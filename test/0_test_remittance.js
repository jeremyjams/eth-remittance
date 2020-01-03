const Remittance = artifacts.require("./Remittance.sol");
const truffleAssert = require('truffle-assertions');

const { BN, soliditySha3 } = web3.utils
require('chai').use(require('chai-bn')(BN)).should();

// ganache-cli --accounts=10 --host=0.0.0.0

contract("Remittance", accounts => {
    describe("Testting Splitter contract", () => {

        let splitter, alice, bob, carol, anyone;

        beforeEach("Fresh contract & accounts", async () => {
            alice = accounts[1]
            bob = accounts[2]
            carol = accounts[3]
            anyone = accounts[9]

            remittance = await Remittance.new("0x0000000000000000000000000000000000000000000000000000000000000001", 0, true, {from: alice, value: 1})


        });

        describe("personHash", () => {
            it("should hash the inputs using keccack256", async () => {
                //const personHash = await personContract.personHash.call();


                const secret1Hex = web3.utils.padRight(web3.utils.asciiToHex("a"), 64)
                console.log(secret1Hex)

                const secret2Hex = web3.utils.padRight(web3.utils.asciiToHex("b"), 64)
                console.log(secret2Hex)


                const soliditySha3Expected = soliditySha3(
                    secret1Hex, secret2Hex
                );

                console.log(soliditySha3Expected)

                //expect(personHash).to.equal(soliditySha3Expected);
            });
        });

    });



});
