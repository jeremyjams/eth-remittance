const Remittance = artifacts.require("./Remittance.sol");
const helper = require('./utils/utils.js');
const truffleAssert = require('truffle-assertions');

const { BN, toBN, soliditySha3 } = web3.utils
require('chai').use(require('chai-bn')(BN)).should();

const HOURS = 3600;
const TWELVE = 12;

// ganache-cli --accounts=10 --host=0.0.0.0

contract("Remittance", accounts => {
    describe("Testing Remittance contract", () => {

        let splitter, alice, bob, carol, anyone, remittance, claimableAfterNHours, secret1, secret2, secret1Hex, secret2Hex, redeemSecretHash;

        beforeEach("Fresh contract & accounts", async () => {
            // accounts
            alice = accounts[0]
            bob = accounts[1]
            carol = accounts[2]
            anyone = accounts[9]

            // secret hashes
            secret1 = "a";
            secret2 = "b";
            secret1Hex = web3.utils.padRight(web3.utils.asciiToHex(secret1), 64);
            secret2Hex = web3.utils.padRight(web3.utils.asciiToHex(secret2), 64);
            redeemSecretHash = soliditySha3(secret1Hex, secret2Hex);

            // deploy Remittance
            claimableAfterNHours = TWELVE;
            remittance = await Remittance.new(redeemSecretHash, claimableAfterNHours, false, {from: alice, value: 1})
            const contractBalance = await web3.eth.getBalance(remittance.address)
            assert.strictEqual(contractBalance.toString(10), "1", "Contract balance should be 1");
        });

        describe("Redeem", () => {
            it("should redeem", async () => {
                // redeem
                const balanceBefore = await web3.eth.getBalance(carol);
                const receipt = await remittance.redeem(secret1Hex, secret2Hex, {from: carol});

                // check redeem
                truffleAssert.eventEmitted(receipt, 'RedeemEvent', { recipient: carol, amount: toBN(1) });

                // redeem amount
                const redeemGasUsed = receipt.receipt.gasUsed;
                const tx = await web3.eth.getTransaction(receipt.tx);
                const redeemGasPrice = tx.gasPrice;
                const redeemCost = toBN(redeemGasUsed).mul(toBN(redeemGasPrice));
                const balanceAfter = await web3.eth.getBalance(carol);
                const effectiveRedeem = toBN(balanceAfter).sub(toBN(balanceBefore))
                    .add(toBN(redeemCost)).toString(10);
                assert.strictEqual(effectiveRedeem.toString(10), "1");
            });
            it("should claim", async () => {
                // time travel to claimable date
                await helper.advanceTimeAndBlock(TWELVE * HOURS);

                // claim
                const balanceBefore = await web3.eth.getBalance(alice);
                const receipt = await remittance.claim({from: alice});

                // check claim
                truffleAssert.eventEmitted(receipt, 'ClaimEvent', { recipient: alice, amount: toBN(1) });

                // claim amount
                const claimGasUsed = receipt.receipt.gasUsed;
                const tx = await web3.eth.getTransaction(receipt.tx);
                const claimGasPrice = tx.gasPrice;
                const claimCost = toBN(claimGasUsed).mul(toBN(claimGasPrice));
                const balanceAfter = await web3.eth.getBalance(alice);
                const effectiveClaim = toBN(balanceAfter).sub(toBN(balanceBefore))
                    .add(toBN(claimCost)).toString(10);
                assert.strictEqual(effectiveClaim.toString(10), "1");
            });
        });

    });
});