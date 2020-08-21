pragma solidity >=0.4.21 <0.7.0;

import "./Pausable.sol";

contract Remittance is Pausable {

    // bytes32 challenge => Grant grant, where challenge is the ID/puzzle of the grant required to solve for redeeming funds
    mapping(bytes32 => Grant) public grants;
    uint public constant MAX_CLAIMABLE_AFTER_N_HOURS = 24 hours;

    struct Grant {
        address sender;
        uint amount;
        uint claimableDate;
    }

    event GrantEvent(bytes32 indexed challenge, address indexed sender, uint amount, uint claimableDate);
    event RedeemEvent(bytes32 indexed challenge, address indexed recipient, uint amount);
    event ClaimEvent(bytes32 indexed challenge, address indexed recipient, uint amount);

    constructor(bool _paused) Pausable(_paused) public {}

    function generateChallenge(address redeemer, bytes32 password) public view returns (bytes32 challenge) {
        require(redeemer != address(0), "Empty redeemer");
        require(password != 0, "Empty password");

        challenge = keccak256(abi.encodePacked(address(this), redeemer, password));
    }

    /*
    * challenge is the ID of the grant
    */
    function grant(bytes32 challenge, uint8 claimableAfterNHours) public payable whenNotPaused {
        require(msg.value > 0, "Funds required");
        require(challenge != 0, "Empty challenge");//prevents locking bad formatted grant
        require(grants[challenge].sender == address(0), "challenge already used by someone");//prevents reusing same secrets
        require(claimableAfterNHours < MAX_CLAIMABLE_AFTER_N_HOURS, "Claim period should be less than 24 hours");//prevents badly formatted construction

        grants[challenge].amount = msg.value;
        grants[challenge].sender = msg.sender;
        grants[challenge].claimableDate = now + claimableAfterNHours * 1 hours;
        emit GrantEvent(challenge, msg.sender, msg.value, grants[challenge].claimableDate);
    }

    /*
    * Note: UTF8-> bytes32 conversion made by web app backend
    *
    * Remove challenge from signature? -> No, it is better to keep challenge in signature. It is more secure to keep it
    * since with it Carol would need to brut force password for all existing public challenges
    *
    */
    function redeem(bytes32 _challenge, bytes32 password) public whenNotPaused whenGrant(_challenge) returns (bool success) {
        require(password != 0, "Empty password");

        bytes32 challenge = generateChallenge(msg.sender, password);
        require(challenge == _challenge, "Invalid password");

        uint amount = grants[challenge].amount;
        grants[challenge].amount = 0;//avoid reentrancy with non-zero amount
        //dont clear grant.sender to avoid reusing same secrets
        emit RedeemEvent(challenge, msg.sender, amount);
        (success,) = msg.sender.call.value(amount)("");
        require(success, "Redeem transfer failed");
    }

    function claim(bytes32 challenge) public whenGrant(challenge) returns (bool success) {
        require(msg.sender == grants[challenge].sender, "Sender is not sender of grant");
        require(now >= grants[challenge].claimableDate, "Should wait claimable date");

        uint amount = grants[challenge].amount;
        grants[challenge].amount = 0;//see redeem() comments
        emit ClaimEvent(challenge, msg.sender, amount);
        (success,) = msg.sender.call.value(amount)("");
        require(success, "Claim transfer failed");
    }

    modifier whenGrant(bytes32 challenge) {
        require(challenge != 0, "Empty challenge");
        require(grants[challenge].amount > 0, "Empty grant");
        _;
    }

}
