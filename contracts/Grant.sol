pragma solidity >=0.4.21 <0.7.0;

import "./Pausable.sol";
import "./SafeMath.sol";
import "./GrantHub.sol";

contract Grant is Ownable{

    using SafeMath for uint;

    address grantHubAddress;
    bytes32 challenge;
    uint claimableDate;

    event RedeemEvent(bytes32 indexed challenge, address indexed recipient, uint amount);
    event ClaimEvent(bytes32 indexed challenge, address indexed recipient, uint amount);
    event WithdrawIncomeEvent(address indexed owner, uint income);

    constructor(address _granter, bytes32 _challenge, uint _claimableDate) public payable {
        grantHubAddress = msg.sender;
        challenge = _challenge;
        claimableDate = _claimableDate;

        transferOwnership(_granter);
    }

    function redeem(bytes32 password) public returns (bool success) {
        bytes32 challenge = GrantHub(grantHubAddress).generateChallenge(msg.sender, password);
        uint amount = address(this).balance;
        require(amount > 0, "Empty grant");

        //avoid reentrancy with non-zero amount
        amount = 0;
        claimableDate = 0;
        emit RedeemEvent(challenge, msg.sender, amount);
        (success,) = msg.sender.call.value(amount)("");
        require(success, "Redeem transfer failed");
    }

    function claim() public returns (bool success) {
        require(challenge != 0, "Empty challenge");
        uint amount = address(this).balance;
        require(amount > 0, "Empty grant");
        require(msg.sender == owner(), "Sender is not sender of grant");
        require(now >= claimableDate, "Should wait claimable date");

        amount = 0;
        claimableDate = 0;
        emit ClaimEvent(challenge, msg.sender, amount);
        (success,) = msg.sender.call.value(amount)("");
        require(success, "Claim transfer failed");
    }

}
