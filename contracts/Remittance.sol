pragma solidity >=0.4.21 <0.7.0;

//import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/lifecycle/Pausable.sol";//TODO move *.sol to current folder

contract Remittance is Pausable {

    bytes32 private redeemSecretHash;

    event RedeemEvent(address recipient, uint amount);

    constructor(bytes32 _redeemSecretHash) Pausable() public payable {
        require(msg.value > 0, "Funds required");
        require(_redeemSecretHash != 0, "Empty RedeemSecretHash"); //prevents badly formatted construction

        redeemSecretHash = _redeemSecretHash;
    }

    /*
    * UTF8-> bytes32 conversion made by web app backend
    */
    function redeem(bytes32 secret1, bytes32 secret2) public returns (bool success) {//should we unlock in 2 steps?
        require(address(this).balance > 0, "Nothing to redeem");

        bytes32 secretHash = keccak256(abi.encodePacked(secret1, secret2));
        require(secretHash == redeemSecretHash, "Unauthorized to redeem");

        emit RedeemEvent(msg.sender, address(this).balance); //is address(this).balance expensive?
        (success,) = msg.sender.call.value(address(this).balance)("");
        require(success, "Redeem transfer failed");
    }

    function() external payable { }


}
