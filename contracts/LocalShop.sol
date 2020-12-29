pragma solidity >=0.4.21 <0.7.0;

import "./Pausable.sol";
import "./SafeMath.sol";
import "./GlobalHub.sol";

contract LocalShop is Pausable{

    using SafeMath for uint;
    // Equals to `bytes4(keccak256("generateChallenge(address,bytes32)"))`
    // which can be also obtained as `GlobalHub(grantHubAddress).generateChallenge.selector`
    bytes4 private constant GLOBAL_HUB_GENERATE_CHALLENGE_SELECTOR = 0x8ad3353b;
    // bytes32 challenge => Grant grant, where challenge is the ID/puzzle of the grant required to solve for redeeming funds
    mapping(bytes32 => Grant) public grants;
    // address owner => uint income, where an owner can withdraw its income
    mapping(address => uint) public incomes;
    address public hubAddress;
    uint public localCut;

    struct Grant {
        address granter;
        uint amount;
        uint claimableDate;
    }

    event LocalShopGrantEvent(address indexed hubAddress, uint amount, bytes32 indexed challenge, uint claimableDate);
    event RedeemEvent(address indexed sender, uint amount, bytes32 indexed challenge);
    event ClaimEvent(address indexed sender, uint amount, bytes32 indexed challenge);
    event NewIncomeEvent(address indexed sender, uint amount);
    event WithdrawIncomeEvent(address indexed sender, uint amount);

    constructor(address _shopOwner, uint _localCut, bool _paused) Pausable(_paused) public {
        hubAddress = msg.sender;
        setLocalCut(_localCut);
        transferOwnership(_shopOwner);
    }

    function setLocalCut(uint _localCut) public whenNotPaused onlyOwner returns (bool) {
        localCut = _localCut;
        return true;
    }

    /*
    * Only accessible though the hub
    */
    function grant(address granter, bytes32 challenge, uint claimableDate) public payable whenNotPaused returns (bool success) {
        require(msg.sender == hubAddress, "Grant feature is only accessible through the GlobalHub");
        require(msg.value > localCut, "Grant should be greater than our cut");

        uint amount;
        if(localCut > 0){
            address owner = owner();
            incomes[owner] = incomes[owner].add(localCut);
            emit NewIncomeEvent(owner, localCut);
            amount = msg.value.sub(localCut);
        } else {
            amount = msg.value;
        }

        grants[challenge].granter = granter;
        grants[challenge].amount = amount;
        grants[challenge].claimableDate = claimableDate;
        emit LocalShopGrantEvent(msg.sender, amount, challenge, claimableDate);
        return true;
    }

    function redeem(bytes32 password) public returns (bool success) {
        (bool isSuccess, bytes memory returnedData) = hubAddress
            .call(abi.encodeWithSelector(GLOBAL_HUB_GENERATE_CHALLENGE_SELECTOR, msg.sender, password));
        require(isSuccess, "Internal call failed: hub.generateChallenge(redeemer, password)");
        bytes32 challenge = abi.decode(returnedData, (bytes32));
        uint amount = grants[challenge].amount;
        require(amount > 0, "Empty grant");

        delete grants[challenge];//secret non reuse is handled in Hub

        emit RedeemEvent(msg.sender, amount, challenge);
        (success,) = msg.sender.call.value(amount)("");
        require(success, "Redeem transfer failed");
    }

    function claim(bytes32 challenge) public whenNotPaused returns (bool success) {
        uint amount = grants[challenge].amount;
        require(amount > 0, "Empty grant");
        require(msg.sender == grants[challenge].granter, "Sender is not granter");
        require(now >= grants[challenge].claimableDate, "Should wait claimable date");

        delete grants[challenge];
        emit ClaimEvent(msg.sender, amount, challenge);
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
