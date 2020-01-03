pragma solidity >=0.4.21 <0.7.0;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/lifecycle/Pausable.sol";//TODO move *.sol to current folder

contract Remittance is Ownable, Pausable {

    bytes32 private redeemSecretHash;
    uint private claimableStartDate;

    event RedeemEvent(address recipient, uint amount);
    event ClaimEvent(address recipient, uint amount);

    constructor(bytes32 _redeemSecretHash, uint8 claimableHoursAfter) Pausable() public payable {
        require(msg.value > 0, "Funds required");
        require(_redeemSecretHash != 0, "Empty RedeemSecretHash"); //prevents badly formatted construction
        require(claimableHoursAfter < 10 days, "Empty RedeemSecretHash"); //prevents badly formatted construction

        redeemSecretHash = _redeemSecretHash;
        claimableStartDate = now + claimableHoursAfter * 1 hours;
    }

    /*
    * UTF8-> bytes32 conversion made by web app backend
    */
    function redeem(bytes32 secret1, bytes32 secret2) public returns (bool success) {//should we unlock in 2 steps?
        require(address(this).balance > 0, "Nothing to redeem");

        bytes32 secretHash = keccak256(abi.encodePacked(secret1, secret2));
        require(secretHash == redeemSecretHash, "Unauthorized to redeem");

        emit RedeemEvent(msg.sender, address(this).balance);
        require(withdraw(), "Redeem transfer failed");
    }

    function withdraw() private returns (bool success) {
        (success,) = msg.sender.call.value(address(this).balance)("");
        require(success, "Withdraw failed");
    }

    function claim() public onlyOwner onlyAfter(claimableStartDate) returns (bool success) {
        require(address(this).balance > 0, "Nothing to claim");

        emit ClaimEvent(msg.sender, address(this).balance);
        require(withdraw(), "Redeem transfer failed");
    }

    modifier onlyAfter(uint time) {
        require(now >= time, "Please wait");
        _;
    }

    function() external payable { }

}
