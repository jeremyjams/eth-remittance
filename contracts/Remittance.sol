pragma solidity >=0.4.21 <0.7.0;

import "./Pausable.sol";
import "./SafeMath.sol";

contract Remittance is Pausable {

    using SafeMath for uint;
    // bytes32 challenge => Grant grant, where challenge is the ID/puzzle of the grant required to solve for redeeming funds
    mapping(bytes32 => Grant) public grants;
    uint public constant MAX_CLAIMABLE_AFTER_N_HOURS = 24 hours;
    uint public cut;
    // address owner => uint income, where an owner can withdraw its income
    mapping(address => uint) public incomes;

    struct Grant {
        address sender;
        uint amount;
        uint claimableDate;
    }

    event GrantEvent(bytes32 indexed challenge, address indexed sender, uint amount, uint claimableDate);
    event RedeemEvent(bytes32 indexed challenge, address indexed recipient, uint amount);
    event ClaimEvent(bytes32 indexed challenge, address indexed recipient, uint amount);
    event NewIncomeEvent(address indexed owner, uint income);
    event WithdrawIncomeEvent(address indexed owner, uint income);

    constructor(bool _paused, uint _cut) Pausable(_paused) public {
        cut = _cut;
    }

    function generateChallenge(address redeemer, bytes32 password) public view returns (bytes32 challenge) {
        require(redeemer != address(0), "Empty redeemer");
        require(password != 0, "Empty password");

        challenge = keccak256(abi.encodePacked(address(this), redeemer, password));
    }

    /*
    * challenge is the ID of the grant
    */
    function grant(bytes32 challenge, uint claimableAfterNHours) public payable whenNotPaused {
        //prevents locking bad formatted grant
        require(challenge != 0, "Empty challenge");
        //prevents reusing same secrets
        require(grants[challenge].sender == address(0), "Challenge already used by someone");
        //prevents badly formatted construction
        require(claimableAfterNHours < MAX_CLAIMABLE_AFTER_N_HOURS, "Claim period should be less than 24 hours");
        require(msg.value > cut, "Grant should be greater than our cut");

        uint amount;
        if(cut > 0){
            address owner = owner();
            incomes[owner] = incomes[owner].add(cut);
            emit NewIncomeEvent(owner, cut);
            amount = msg.value.sub(cut);
        } else {
            amount = msg.value;
        }

        grants[challenge].amount = amount;
        grants[challenge].sender = msg.sender;
        grants[challenge].claimableDate = now.add(claimableAfterNHours.mul(1 hours));
        emit GrantEvent(challenge, msg.sender, amount, grants[challenge].claimableDate);
    }

    /*
    * Note: UTF8-> bytes32 conversion made by web app backend
    *
    * Remove challenge from signature? -> No, it is better to keep challenge in signature. It is more secure to keep it
    * since with it Carol would need to brut force password for all existing public challenges
    *
    */
    function redeem(bytes32 password) public whenNotPaused returns (bool success) {
        bytes32 challenge = generateChallenge(msg.sender, password);
        uint amount = grants[challenge].amount;
        require(amount > 0, "Empty grant");

        //avoid reentrancy with non-zero amount
        grants[challenge].amount = 0;
        grants[challenge].claimableDate = 0;
        //dont clear grant.sender to avoid reusing same secrets
        emit RedeemEvent(challenge, msg.sender, amount);
        (success,) = msg.sender.call.value(amount)("");
        require(success, "Redeem transfer failed");
    }

    function claim(bytes32 challenge) public whenNotPaused returns (bool success) {
        require(challenge != 0, "Empty challenge");
        uint amount = grants[challenge].amount;
        require(amount > 0, "Empty grant");
        require(msg.sender == grants[challenge].sender, "Sender is not sender of grant");
        require(now >= grants[challenge].claimableDate, "Should wait claimable date");

        //see redeem() comments
        grants[challenge].amount = 0;
        emit ClaimEvent(challenge, msg.sender, amount);
        (success,) = msg.sender.call.value(amount)("");
        require(success, "Claim transfer failed");
    }

    /*
     * Anyone with income can withdraw it
     */
    function withdrawIncome() public whenNotPaused returns (bool success) {
        uint income = incomes[msg.sender];
        require(income > 0, "Empty income");
        incomes[msg.sender] = 0;
        emit WithdrawIncomeEvent(msg.sender, income);
        (success,) = msg.sender.call.value(income)("");
        require(success, "WithdrawIncome transfer failed");
    }

}
