const Remittance = artifacts.require("Remittance");
const { BN, toBN, soliditySha3 } = web3.utils
const ETH_CUT = '0.01';
const CUT = web3.utils.toWei(ETH_CUT, 'ether');

module.exports = function(deployer) {
  deployer.deploy(Remittance, true, CUT);
};
