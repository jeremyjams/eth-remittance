const Remittance = artifacts.require("Remittance");

module.exports = function(deployer) {
  deployer.deploy(Remittance, "0x0000000000000000000000000000000000000000000000000000000000000001", 0, true, {value: 1});
};
