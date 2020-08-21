pragma solidity >=0.4.21 <0.7.0;

library Challenge {

    function generate(address salt, address redeemer, bytes32 password) public pure returns (bytes32 challenge) {
        require(salt != address(0), "Empty salt");
        require(redeemer != address(0), "Empty redeemer");
        require(password != 0, "Empty password");

        challenge = keccak256(abi.encodePacked(salt, redeemer, password));
    }

}
