const Remittance = artifacts.require("./Remittance.sol");
const Challenge = artifacts.require("./Challenge.sol");
const helper = require('./utils/utils.js');
const truffleAssert = require('truffle-assertions');

const { BN, toBN, soliditySha3 } = web3.utils
require('chai').use(require('chai-bn')(BN)).should();

const HOURS = 3600;
const TWELVE = 12;

// ganache-cli --accounts=10 --host=0.0.0.0

contract("Remittance", accounts => {
    describe("Testing Remittance contract", () => {

        let remittance, alice, bob, carol, anyone, claimableAfterNHours, password, hexPassword, challenge, challengeLib;

        beforeEach("Fresh contract & accounts", async () => {
            // accounts
            alice = accounts[0]
            bob = accounts[1]
            carol = accounts[2]
            anyone = accounts[9]

            // deploy Remittance
            claimableAfterNHours = TWELVE;
            remittance = await Remittance.new(claimableAfterNHours, false, {from: carol});

            // deploy challenge lib
            challengeLib = await Challenge.new({from: carol});

            // challenge & password
            password = "p4ssw0rd";
            hexPassword = web3.utils.padRight(web3.utils.asciiToHex(password), 64);
            challenge = soliditySha3(remittance.address, carol, hexPassword);
        });

        describe("Challenge", () => {
            it("should generate challenge", async () => {
                const generatedChallenge = await challengeLib.generate.call(remittance.address, carol, hexPassword);
                assert.strictEqual(generatedChallenge, challenge, "Generated challenge should be valid");
            });
            it("should not generate challenge since", async () => {
                //TODO
            });
        });

        describe("Grant", () => {
            it("should grant", async () => {
                //grant
                const grantReceipt = await remittance.grant(challenge, {from: alice, value: 1});
                truffleAssert.eventEmitted(grantReceipt, 'GrantEvent', { challenge: challenge, sender: alice, amount: toBN(1) }); //move to grant test
                const grant = await remittance.grants(challenge);
                assert.strictEqual(grant.amount.toString(10), "1", "Grant amount should be 1");
            });
            it("should not grant since", async () => {
                //TODO
            });
        });

        describe("Redeem", () => {
            it("should redeem", async () => {
                //grant
                await remittance.grant(challenge, {from: alice, value: 1});

                // redeem
                const balanceBefore = await web3.eth.getBalance(carol);
                const receipt = await remittance.redeem(challenge, hexPassword, {from: carol});

                // check redeem
                truffleAssert.eventEmitted(receipt, 'RedeemEvent', { challenge: challenge, recipient: carol, amount: toBN(1) });

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
                await remittance.grant(challenge, {from: alice, value: 1});

                // time travel to claimable date
                await helper.advanceTimeAndBlock(TWELVE * HOURS);

                // claim
                const balanceBefore = await web3.eth.getBalance(alice);
                const receipt = await remittance.claim(challenge, {from: alice});

                // check claim
                truffleAssert.eventEmitted(receipt, 'ClaimEvent', { challenge: challenge, recipient: alice, amount: toBN(1) });

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