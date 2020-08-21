const Remittance = artifacts.require("Remittance");
const Challenge = artifacts.require("./Challenge.sol");

module.exports = function(deployer) {
  deployer.deploy(Challenge);
  deployer.link(Challenge, Remittance);
  deployer.deploy(Remittance, 12, true);
};
