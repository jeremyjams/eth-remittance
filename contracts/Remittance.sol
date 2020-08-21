pragma solidity >=0.4.21 <0.7.0;

import "./Pausable.sol";
import "./Challenge.sol";

contract Remittance is Pausable {

    uint private claimableDate;
    mapping(bytes32 => Grant) public grants;

    struct Grant {
        address sender;
        uint amount;
    }

    event GrantEvent(bytes32 challenge, address sender, uint amount);
    event RedeemEvent(bytes32 challenge, address recipient, uint amount);
    event ClaimEvent(bytes32 challenge, address recipient, uint amount);

    constructor(uint8 _claimableAfterNHours, bool _paused) Pausable(_paused) public {
        require(_claimableAfterNHours < 24 hours, "Claim period should be less than 24 hours");//prevents badly formatted construction

        claimableDate = now + _claimableAfterNHours * 1 hours;
    }

    /*
    * challenge is the ID of the grant
    */
    function grant(bytes32 challenge) public payable whenNotPaused {
        require(msg.value > 0, "Funds required");
        require(challenge != 0, "Empty challenge");//prevents locking bad formatted grant
        require(grants[challenge].sender == address(0), "SecretHash already used by someone");//prevents reusing same secrets

        grants[challenge].amount = msg.value;
        grants[challenge].sender = msg.sender;
        emit GrantEvent(challenge, msg.sender, msg.value);
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

        bytes32 challenge = Challenge.generate(address(this), msg.sender, password);
        //bytes32 challenge = keccak256(abi.encodePacked(address(this), msg.sender, password));
        require(challenge == _challenge, "Unauthorized to redeem");

        uint amount = grants[challenge].amount;
        grants[challenge].amount = 0;//avoid reentrancy with non-zero amount
        //dont clear grant.sender to avoid reusing same secrets
        emit RedeemEvent(challenge, msg.sender, amount);
        (success,) = msg.sender.call.value(amount)("");
        require(success, "Redeem transfer failed");
    }

    function claim(bytes32 challenge) public onlyAfter(claimableDate) whenGrant(challenge) returns (bool success) {
        require(msg.sender == grants[challenge].sender, "Granter required");

        uint amount = grants[challenge].amount;
        grants[challenge].amount = 0;//see redeem() comments
        emit ClaimEvent(challenge, msg.sender, amount);
        (success,) = msg.sender.call.value(amount)("");
        require(success, "Claim transfer failed");
    }

    modifier onlyAfter(uint time) {
        require(now >= time, "Please wait");
        _;
    }

    modifier whenGrant(bytes32 challenge) {
        require(challenge != 0, "Empty challenge");
        require(grants[challenge].amount > 0, "Empty grant");
        _;
    }

    function() external payable {}

}
