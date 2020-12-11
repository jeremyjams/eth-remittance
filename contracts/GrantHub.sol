pragma solidity >=0.4.21 <0.7.0;

import "./Pausable.sol";
import "./SafeMath.sol";
import "./GrantHub.sol";
import "./Grant.sol";

contract GrantHub is Pausable {

    using SafeMath for uint;

    uint public constant MAX_CLAIMABLE_AFTER_N_HOURS = 24 hours;
    uint public cut;
    mapping(bytes32 => bool) public isChallengeUsedList;
    // address owner => uint income, where an owner can withdraw its income
    mapping(address => uint) public incomes;

    event GrantEvent(bytes32 indexed challenge, address indexed recipient, uint amount, uint claimableDate, address indexed grantContract);
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
    function grant(bytes32 challenge, uint claimableAfterNHours) public payable whenNotPaused returns (bool) {
        //prevents locking bad formatted grant
        require(challenge != 0, "Empty challenge");
        //prevents reusing same secrets
        require(isChallengeUsedList[challenge] == false, "Challenge already used by someone");
        //prevents badly formatted construction
        require(claimableAfterNHours < MAX_CLAIMABLE_AFTER_N_HOURS, "Claim period should be less than 24 hours");
        require(msg.value > cut, "Grant should be greater than our cut");

        isChallengeUsedList[challenge] = true;

        uint amount;
        if(cut > 0){
            address owner = owner();
            incomes[owner] = incomes[owner].add(cut);
            emit NewIncomeEvent(owner, cut);
            amount = msg.value.sub(cut);
        } else {
            amount = msg.value;
        }

        uint claimableDate = now.add(claimableAfterNHours.mul(1 hours));

        Grant grant = (new Grant).value(msg.value)(msg.sender, challenge, claimableDate);
        require(address(grant) != address(0), "Failed to create Grant contract");
        emit GrantEvent(challenge, msg.sender, amount, claimableDate, address(grant));
        return true;
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
