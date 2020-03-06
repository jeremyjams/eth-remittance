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

        let remittance, alice, bob, carol, anyone, claimableAfterNHours, secret1, secret2, secret1Hex, secret2Hex, redeemSecretHash;

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
            remittance = await Remittance.new(claimableAfterNHours, false, {from: carol});
        });

        describe("Grant", () => {
            it("should grant", async () => {
                //grant
                const grantReceipt = await remittance.grant(redeemSecretHash, {from: alice, value: 1});
                truffleAssert.eventEmitted(grantReceipt, 'GrantEvent', { secretHash: redeemSecretHash, sender: alice, amount: toBN(1) }); //move to grant test
                const grant = await remittance.grants(redeemSecretHash);
                console.log(grant.amount)
                assert.strictEqual(grant.amount.toString(10), "1", "Grant amount should be 1");
            });
            it("should not grant since", async () => {
                //TODO
            });
        });

        describe("Redeem", () => {
            it("should redeem", async () => {
                //grant
                await remittance.grant(redeemSecretHash, {from: alice, value: 1});

                // redeem
                const balanceBefore = await web3.eth.getBalance(carol);
                const receipt = await remittance.redeem(redeemSecretHash, secret1Hex, secret2Hex, {from: carol});

                // check redeem
                truffleAssert.eventEmitted(receipt, 'RedeemEvent', { secretHash: redeemSecretHash, recipient: carol, amount: toBN(1) });

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
            it("should not redeem since", async () => {
                //TODO
            });
        });

        describe("Claim", () => {
            it("should claim", async () => {
                //grant
                await remittance.grant(redeemSecretHash, {from: alice, value: 1});

                // time travel to claimable date
                await helper.advanceTimeAndBlock(TWELVE * HOURS);

                // claim
                const balanceBefore = await web3.eth.getBalance(alice);
                const receipt = await remittance.claim(redeemSecretHash, {from: alice});

                // check claim
                truffleAssert.eventEmitted(receipt, 'ClaimEvent', { secretHash: redeemSecretHash, recipient: alice, amount: toBN(1) });

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
            it("should not claim since", async () => {
                //TODO
            });
        });

    });
});