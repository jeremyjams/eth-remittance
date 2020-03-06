pragma solidity >=0.4.21 <0.7.0;

import "./Pausable.sol";

contract Remittance is Pausable {

    uint private claimableDate;
    mapping(bytes32 => Grant) public grants;

    struct Grant {
        address sender;
        uint amount;
    }

    event GrantEvent(bytes32 secretHash, address sender, uint amount);
    event RedeemEvent(bytes32 secretHash, address recipient, uint amount);
    event ClaimEvent(bytes32 secretHash, address recipient, uint amount);

    constructor(uint8 _claimableAfterNHours, bool _paused) Pausable(_paused) public {
        require(_claimableAfterNHours < 24 hours, "Claim period should be less than 24 hours");//prevents badly formatted construction

        claimableDate = now + _claimableAfterNHours * 1 hours;
    }

    /*
    * secretHash is the ID of the grant //TODO rename?
    */
    function grant(bytes32 secretHash) public payable whenNotPaused {
        require(msg.value > 0, "Funds required");
        require(secretHash != 0, "Empty RedeemSecretHash");//prevents locking bad formatted grant
        require(grants[secretHash].amount == 0, "SecretHash collision");//prevents overwriting existing grant

        grants[secretHash].amount = msg.value;
        grants[secretHash].sender = msg.sender;
        emit GrantEvent(secretHash, msg.sender, msg.value);
    }

    /*
    * UTF8-> bytes32 conversion made by web app backend
    */
    //TODO think: beware if transaction is reverted but secrets already leaked?
    function redeem(bytes32 _secretHash, bytes32 secret1, bytes32 secret2) public whenNotPaused whenGrant(_secretHash) returns (bool success) {//should we unlock in 2 steps?
        require(secret1 != 0, "Empty secret1");
        require(secret2 != 0, "Empty secret2");

        bytes32 secretHash = keccak256(abi.encodePacked(secret1, secret2));
        require(secretHash == _secretHash, "Unauthorized to redeem");

        uint amount = grants[secretHash].amount;
        grants[secretHash].amount = 0;
        emit RedeemEvent(secretHash, msg.sender, amount);
        (success,) = msg.sender.call.value(amount)("");
        require(success, "Redeem transfer failed");
    }

    function claim(bytes32 secretHash) public onlyAfter(claimableDate) whenGrant(secretHash) returns (bool success) {
        require(msg.sender == grants[secretHash].sender, "Granter required");

        uint amount = grants[secretHash].amount;
        grants[secretHash].amount = 0;
        emit ClaimEvent(secretHash, msg.sender, amount);
        (success,) = msg.sender.call.value(amount)("");
        require(success, "Claim transfer failed");
    }

    modifier onlyAfter(uint time) {
        require(now >= time, "Please wait");
        _;
    }

    modifier whenGrant(bytes32 secretHash) {
        require(secretHash != 0, "Empty secretHash");
        require(grants[secretHash].amount > 0, "Empty grant");
        _;
    }

    function() external payable {}

}
