const Remittance = artifacts.require("Remittance");
const { BN, toBN, soliditySha3, toWei } = web3.utils
const ETH_CUT = '0.01';
const CUT = toWei(ETH_CUT, 'ether');

module.exports = function(deployer) {
  deployer.deploy(Remittance, true, CUT);
};
