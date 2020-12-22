const Remittance = artifacts.require("./GrantHub.sol");
const Grant = artifacts.require("./Grant.sol");
const helper = require('./utils/utils.js');
const truffleAssert = require('truffle-assertions');
const timeMachine = require('ganache-time-traveler');

const { BN, toBN, soliditySha3, fromWei, padRight, asciiToHex } = web3.utils
require('chai').use(require('chai-bn')(BN)).should();

const HOURS = 3600;
const CLAIMABLE_AFTER_12_HOURS = 12;
const GRANT_AMOUNT = 2;
const CUT = 1;

// ganache-cli --accounts=10 --host=0.0.0.0

contract("Remittance", accounts => {
    describe("Testing Remittance contract", () => {

        let remittance, challenge;
        // accounts
        const [ alice, bob, carol, david, anyone ] = accounts;
        // challenge & password
        let password = "p4ssw0rd";
        let hexPassword = padRight(asciiToHex(password), 64);

        before("Deploy to estimate gas cost", async () => {
            const balanceBefore = await web3.eth.getBalance(accounts[0]);
            remittance = await Remittance.new(false, 0, {from: accounts[0]});
            const balanceAfter = await web3.eth.getBalance(accounts[0]);
            const deployCost = toBN(balanceBefore).sub(toBN(balanceAfter));
            console.log("Deploy cost:             " + fromWei(deployCost.toString(10), 'ether') + "ETH")
            console.log("Cut cost:                " + fromWei(CUT.toString(10), 'ether') + "ETH")
            console.log("generateChall. selector: " + soliditySha3("generateChallenge(address,bytes32)"))
        });

        beforeEach("Fresh contract & accounts", async () => {
            // deploy Remittance
            remittance = await Remittance.new(false, CUT, {from: carol});
            // challenge
            challenge = await remittance.generateChallenge.call(carol, hexPassword);
        });

        describe("Challenge", () => {
            it("should generate challenge", async () => {
                const expectedChallenge = soliditySha3(remittance.address, carol, hexPassword);
                assert.strictEqual(challenge, expectedChallenge, "Generated challenge should be valid");
            });
            it("should generate salted challenges with same parameters", async () => {
                let anotherRemittance = await Remittance.new(false, CUT, {from: carol});
                assert.notEqual( soliditySha3(remittance.address, carol, hexPassword),
                    soliditySha3(anotherRemittance.address, carol, hexPassword), "Generated challenge should be different");
            });
        });

        describe("Grant", () => {
            it("should grant", async () => {
                remittance = await Remittance.new(false, 0, {from: carol});
                //grant
                const grantReceipt = await remittance.grant(challenge, CLAIMABLE_AFTER_12_HOURS, {from: alice, value: GRANT_AMOUNT});
                const lastBlock = await web3.eth.getBlock(grantReceipt.receipt.blockNumber)
                const now = lastBlock.timestamp

                truffleAssert.eventEmitted(grantReceipt, 'GrantEvent', { sender: alice,
                    amount: toBN(2), challenge: challenge, claimableDate: toBN(now + 12 * 3600) });
                const isChallengeUsed = await remittance.isChallengeUsedList(challenge);
                assert.strictEqual(isChallengeUsed, true, "Challenge shout be used");
                const grandAddress = grantReceipt.logs[2].args.grantContract
                const grant = await Grant.at(grandAddress);
                const amount = await grant.amount();
                assert.strictEqual(amount.toString(10), "2", "Grant amount should be 2");
            });
            /*
            it("should grant with cut", async () => {
                //grant
                const grantReceipt = await remittance.grant(challenge, CLAIMABLE_AFTER_12_HOURS, {from: alice, value: GRANT_AMOUNT});
                const lastBlock = await web3.eth.getBlock(grantReceipt.receipt.blockNumber)
                const now = lastBlock.timestamp

                truffleAssert.eventEmitted(grantReceipt, 'GrantEvent', { sender: alice,
                    amount: toBN(1), challenge: challenge, claimableDate: toBN(now + 12 * 3600) });
                truffleAssert.eventEmitted(grantReceipt, 'NewIncomeEvent', { sender: carol, income: toBN(1) });
                const grant = await remittance.grants(challenge);
                assert.strictEqual(grant.amount.toString(10), "1", "Grant amount should be 1");
            });
            it("should not grant since grant lower than cut", async () => {
                // grant with already used challenge
                await truffleAssert.reverts(
                    remittance.grant(challenge, CLAIMABLE_AFTER_12_HOURS, {from: anyone, value: 1}),
                    "Grant should be greater than our cut"
                );
            });
            it("should not grant since already use challenge", async () => {
                // grant
                const grantReceipt = await remittance.grant(challenge, CLAIMABLE_AFTER_12_HOURS, {from: alice, value: GRANT_AMOUNT});

                // grant with already used challenge
                await truffleAssert.reverts(
                    remittance.grant(challenge, CLAIMABLE_AFTER_12_HOURS, {from: anyone, value: GRANT_AMOUNT}),
                    "Challenge already used by someone"
                );
            });
            */
        });
        /*
        describe("Redeem", () => {
            it("should redeem", async () => {
                //grant
                await remittance.grant(challenge, CLAIMABLE_AFTER_12_HOURS, {from: alice, value: GRANT_AMOUNT});

                // redeem
                const balanceBefore = await web3.eth.getBalance(carol);
                const receipt = await remittance.redeem(hexPassword, {from: carol});

                // check redeem
                truffleAssert.eventEmitted(receipt, 'RedeemEvent', { recipient: carol, amount: toBN(1), challenge: challenge});

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
                await remittance.grant(challenge, CLAIMABLE_AFTER_12_HOURS, {from: alice, value: GRANT_AMOUNT});

                // redeem
                await truffleAssert.reverts(
                    remittance.redeem(hexPassword, {from: anyone}),
                    "Empty grant"
                );
            });
            it("should not redeem since bad password", async () => {
                //grant
                await remittance.grant(challenge, CLAIMABLE_AFTER_12_HOURS, {from: alice, value: GRANT_AMOUNT});

                // redeem
                badHexPassword = padRight(asciiToHex("b4dpwd"), 64);
                await truffleAssert.reverts(
                    remittance.redeem(badHexPassword, {from: carol}),
                    "Empty grant"
                );
            });
        });

        describe("Claim", () => {
            it("should claim", async () => {
                //grant
                await remittance.grant(challenge, CLAIMABLE_AFTER_12_HOURS, {from: alice, value: GRANT_AMOUNT});

                // time travel to claimable date
                await timeMachine.advanceTimeAndBlock(CLAIMABLE_AFTER_12_HOURS * HOURS);

                // claim
                const balanceBefore = await web3.eth.getBalance(alice);
                const receipt = await remittance.claim(challenge, {from: alice});

                // check claim
                truffleAssert.eventEmitted(receipt, 'ClaimEvent', { sender: alice, amount: toBN(1), challenge: challenge });

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
                await remittance.grant(challenge, CLAIMABLE_AFTER_12_HOURS, {from: alice, value: GRANT_AMOUNT});

                // claim
                const balanceBefore = await web3.eth.getBalance(alice);
                await truffleAssert.reverts(
                    remittance.claim(challenge, {from: alice}),
                    "Should wait claimable date"
                );
            });
            it("should not claim since not sender of grant", async () => {
                //grant
                await remittance.grant(challenge, CLAIMABLE_AFTER_12_HOURS, {from: anyone, value: GRANT_AMOUNT});

                // claim
                const balanceBefore = await web3.eth.getBalance(alice);
                await truffleAssert.reverts(
                    remittance.claim(challenge, {from: alice}),
                    "Sender is not sender of grant"
                );
            });
        });

        describe("Withdraw Income", () => {
            it("should withdraw income", async () => {
                // grant
                await remittance.grant(challenge, CLAIMABLE_AFTER_12_HOURS, {from: anyone, value: GRANT_AMOUNT});

                // withdrawIncome
                const balanceBefore = await web3.eth.getBalance(carol);
                const receipt = await remittance.withdrawIncome({from: carol});

                // check withdrawIncome
                truffleAssert.eventEmitted(receipt, 'WithdrawIncomeEvent', { sender: carol, income: toBN(1) });

                // withdrawIncome amount
                const withdrawIncomeGasUsed = receipt.receipt.gasUsed;
                const tx = await web3.eth.getTransaction(receipt.tx);
                const withdrawIncomeGasPrice = tx.gasPrice;
                const withdrawIncomeCost = toBN(withdrawIncomeGasUsed).mul(toBN(withdrawIncomeGasPrice));
                const balanceAfter = await web3.eth.getBalance(carol);
                const effectiveWithdrawIncome = toBN(balanceAfter).sub(toBN(balanceBefore))
                     .add(toBN(withdrawIncomeCost)).toString(10);
                assert.strictEqual(effectiveWithdrawIncome.toString(10), "1");
            });
            it("should not withdraw income since wrong owner", async () => {
                //grant
                await remittance.grant(challenge, CLAIMABLE_AFTER_12_HOURS, {from: alice, value: GRANT_AMOUNT});

                // claim
                await truffleAssert.reverts(
                    remittance.withdrawIncome({from: anyone}),
                    "Empty income"
                );
            });
        });
        */

    });
});