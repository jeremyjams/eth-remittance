const GlobalHub = artifacts.require("GlobalHub.sol");
const { BN, toBN, soliditySha3, toWei } = web3.utils
const ETH_CUT = '0.01';
const CUT = toWei(ETH_CUT, 'ether');

module.exports = function(deployer) {
  deployer.deploy(GlobalHub, false, CUT);
};
