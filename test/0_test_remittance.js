const Remittance = artifacts.require("./Remittance.sol");
const helper = require('./utils/utils.js');
const truffleAssert = require('truffle-assertions');
const timeMachine = require('ganache-time-traveler');

const { BN, toBN, soliditySha3 } = web3.utils
require('chai').use(require('chai-bn')(BN)).should();

const HOURS = 3600;
const TWELVE = 12;
const GRANT_AMOUNT = 2;
const CUT = 1;

// ganache-cli --accounts=10 --host=0.0.0.0

contract("Remittance", accounts => {
    describe("Testing Remittance contract", () => {

        let remittance, deployCost, alice, bob, carol, anyone, claimableAfterTwelveHours, password, hexPassword, challenge;

        before("Deploy to estimate gas cost", async () => {
            claimableAfterTwelveHours = TWELVE;

            const balanceBefore = await web3.eth.getBalance(accounts[0]);
            remittance = await Remittance.new(false, 0, {from: accounts[0]});
            const balanceAfter = await web3.eth.getBalance(accounts[0]);
            const deployCost = toBN(balanceBefore).sub(toBN(balanceAfter));
            console.log("Deploy cost:   " + web3.utils.fromWei(deployCost.toString(10), 'ether') + "ETH")
            console.log("Cut cost:      " + web3.utils.fromWei(CUT.toString(10), 'ether') + "ETH")
        });

        beforeEach("Fresh contract & accounts", async () => {
            // accounts
            alice = accounts[0]
            bob = accounts[1]
            carol = accounts[2]
            anyone = accounts[9]

            // deploy Remittance
            claimableAfterTwelveHours = TWELVE;
            remittance = await Remittance.new(false, CUT, {from: carol});

            // challenge & password
            password = "p4ssw0rd";
            hexPassword = web3.utils.padRight(web3.utils.asciiToHex(password), 64);
            challenge = await remittance.generateChallenge.call(carol, hexPassword);
        });

        describe("Challenge", () => {
            it("should generate challenge", async () => {
                const expectedChallenge = soliditySha3(remittance.address, carol, hexPassword);
                assert.strictEqual(challenge, expectedChallenge, "Generated challenge should be valid");
            });
            it("should not generate challenge since", async () => {
                //TODO
            });
        });

        describe("Grant", () => {
            it("should grant", async () => {
                //grant
                const grantReceipt = await remittance.grant(challenge, claimableAfterTwelveHours, {from: alice, value: GRANT_AMOUNT});
                const lastBlock = await web3.eth.getBlock("latest")
                const now = lastBlock.timestamp

                truffleAssert.eventEmitted(grantReceipt, 'GrantEvent', { challenge: challenge, sender: alice,
                    amount: toBN(1), claimableDate: toBN(now + 12 * 3600) }); //move to grant test
                const grant = await remittance.grants(challenge);
                assert.strictEqual(grant.amount.toString(10), "1", "Grant amount should be 1");
            });
            it("should not grant since grant lower than cut", async () => {
                // grant with already used challenge
                await truffleAssert.reverts(
                    remittance.grant(challenge, claimableAfterTwelveHours, {from: anyone, value: 1}),
                    "Grant should be greater than our cut"
                );
            });
            it("should not grant since already use challenge", async () => {
                // grant
                const grantReceipt = await remittance.grant(challenge, claimableAfterTwelveHours, {from: alice, value: GRANT_AMOUNT});

                // grant with already used challenge
                await truffleAssert.reverts(
                    remittance.grant(challenge, claimableAfterTwelveHours, {from: anyone, value: GRANT_AMOUNT}),
                    "Challenge already used by someone"
                );
            });
        });

        describe("Redeem", () => {
            it("should redeem", async () => {
                //grant
                await remittance.grant(challenge, claimableAfterTwelveHours, {from: alice, value: GRANT_AMOUNT});

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
            it("should not redeem since bad sender", async () => {
                //grant
                await remittance.grant(challenge, claimableAfterTwelveHours, {from: alice, value: GRANT_AMOUNT});

                // redeem
                await truffleAssert.reverts(
                    remittance.redeem(challenge, hexPassword, {from: anyone}),
                    "Invalid sender or password"
                );
            });
            it("should not redeem since bad password", async () => {
                //grant
                await remittance.grant(challenge, claimableAfterTwelveHours, {from: alice, value: GRANT_AMOUNT});

                // redeem
                badHexPassword = web3.utils.padRight(web3.utils.asciiToHex("b4dpwd"), 64);
                await truffleAssert.reverts(
                    remittance.redeem(challenge, badHexPassword, {from: carol}),
                    "Invalid sender or password"
                );
            });
        });

        describe("Claim", () => {
            it("should claim", async () => {
                //grant
                await remittance.grant(challenge, claimableAfterTwelveHours, {from: alice, value: GRANT_AMOUNT});

                // time travel to claimable date
                await timeMachine.advanceTimeAndBlock(TWELVE * HOURS);

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
            it("should not claim since not after clamable date", async () => {
                //grant
                await remittance.grant(challenge, claimableAfterTwelveHours, {from: alice, value: GRANT_AMOUNT});

                // claim
                const balanceBefore = await web3.eth.getBalance(alice);
                await truffleAssert.reverts(
                    remittance.claim(challenge, {from: alice}),
                    "Should wait claimable date"
                );
            });
            it("should not claim since not sender of grant", async () => {
                //grant
                await remittance.grant(challenge, claimableAfterTwelveHours, {from: anyone, value: GRANT_AMOUNT});

                // claim
                const balanceBefore = await web3.eth.getBalance(alice);
                await truffleAssert.reverts(
                    remittance.claim(challenge, {from: alice}),
                    "Sender is not sender of grant"
                );
            });
        });

    });
});