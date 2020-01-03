pragma solidity >=0.4.21 <0.7.0;

import "@openzeppelin/contracts/ownership/Ownable.sol";
//import "./Ownable.sol"; //TODO

contract Pausable is Ownable {

    event Paused(address account);
    event Unpaused(address account);
    event Killed(address account);

    bool private paused;
    bool private killed;//false by default

    constructor (bool _paused) internal {
        paused = _paused;
    }

    function isPaused() public view returns (bool) {
        return paused;
    }

    function isKilled() public view returns (bool) {
        return killed;
    }

    modifier whenNotPaused() {
        require(!killed, "Pausable: Should be alive");
        require(!paused, "Pausable: paused");
        _;
    }

    modifier whenPaused() {
        require(!killed, "Pausable: Should be alive");
        require(paused, "Pausable: not paused");
        _;
    }

    modifier whenKilled  {
        require(killed, "Should be killed");
        _;
    }

    function pause() public onlyOwner whenNotPaused {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() public onlyOwner whenPaused {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function kill() public onlyOwner whenPaused {
        killed = true;

        emit Killed(msg.sender);
    }
}
