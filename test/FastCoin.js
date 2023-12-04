const {
    loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
    OPEN_REQUEST_TYPES,
    CLOSE_REQUEST_TYPES,
    HOLD_REQUEST_TYPES,
    INCREASE_REQUEST_TYPES,
    DECREASE_REQUEST_TYPES,
    getDomain,
} = require("./Helper");

const ERC20_NAME = "test erc20 name";
const ERC20_SYMBOL = "tts";
const EIP721_NAME = "test erc721 name";
const EIP721_VERSION = "0.0.1";


describe("FastCoin", function () {
    async function deployContract() {
        const [owner, user1, user2, user3] = await ethers.getSigners();
        const Contract = await ethers.getContractFactory("FastCoin");
        const contract = await Contract.deploy(ERC20_NAME, ERC20_SYMBOL, EIP721_NAME, EIP721_VERSION);
        return { contract, owner, user1, user2, user3 };
    }
    describe("Deployment", function () {
        it("Check ERC20 name and symbol, EIP712 name and version", async function () {
            const { contract, owner, user1, user2, user3 } = await loadFixture(deployContract);
            expect(await contract.name()).to.equal(ERC20_NAME);
            expect(await contract.symbol()).to.equal(ERC20_SYMBOL);
            let domain = await contract.eip712Domain();
            expect(domain.name).to.equal(EIP721_NAME);
            expect(domain.version).to.equal(EIP721_VERSION);
        });
    });
    describe("Channel", function () {
        it("Check Channel Address", async function () {
            const { contract, owner, user1, user2, user3 } = await loadFixture(deployContract);
            let addressList = await contract.connect(user2).addressList(user1.address);
            let address1 = addressList.channel;
            addressList = await contract.connect(user1).addressList(user2.address);
            let address2 = addressList.channel;
            expect(address1).to.equal(address2);
            let hash = null;
            if (BigInt(user1.address) < BigInt(user2.address)) {
                hash = ethers.keccak256(user1.address + user2.address.substring(2));
            } else {
                hash = ethers.keccak256(user2.address + user1.address.substring(2));
            }
            let address3 = ethers.getAddress("0x" + hash.substring(26));
            expect(address1).to.equal(address3);
        });
        it("Check Init Channel Info", async function () {
            const { contract, owner, user1, user2, user3 } = await loadFixture(deployContract);
            let info = await contract.channelInfoOf(ethers.ZeroAddress);
            expect(info.index).to.equal(0n);
            expect(info.amount1).to.equal(0n);
            expect(info.amount2).to.equal(0n);
            expect(info.count).to.equal(0n);
            expect(info.locktime).to.equal(0n);
        });
    });
    describe("One Test", function () {
        it("Open -> Increase -> Decrease -> Hold -> Close", async function () {
            const { contract, owner, user1, user2, user3 } = await loadFixture(deployContract);
            let tx = await contract.connect(user1).deposit({ value: ethers.parseEther("0.1") });
            await contract.connect(user2).deposit({ value: ethers.parseEther("0.1") });
            let addressList = await contract.connect(user2).addressList(user1.address);
            let channel = addressList.channel;
            console.log(await contract.balanceOf(user1.address));
            console.log(await contract.balanceOf(user2.address));
            console.log(await contract.balanceOf(channel));
            let val = await ethers.provider.getBalance(user1.address);
            console.log(await ethers.provider.getBalance(user1.address));
            console.log(await ethers.provider.getBalance(user2.address));
            console.log(tx.hash);
            let tr = await ethers.provider.getTransactionReceipt(tx.hash);
            console.log(val + tr.gasUsed * tr.gasPrice);
            let domain = await getDomain(contract);
            // Open
            console.log(">>> Open");
            let value = {
                channel: channel,
                index: await contract.connect(user2).channelIndexOf(channel),
                total: 14500n + 500n,
                amount1: 14500n,
                amount2: 500n,
                nonce: await contract.connect(user2).nonces(user2.address),
                deadline: (Math.floor(Date.now() / 1000) + 3600),
            };
            let sign = await user2.signTypedData(domain, OPEN_REQUEST_TYPES, value);
            let request = {
                partner: user2.address,
                total: value.total,
                amount1: value.amount1,
                amount2: value.amount2,
                deadline: value.deadline,
                signature: sign,
            };
            let result = await contract.connect(user1).verifyOpen(request);
            console.log(result);
            await contract.connect(user1).open(request);
            let info = await contract.channelInfoOf(channel);
            console.log(info);
            console.log(await contract.balanceOf(user1.address));
            console.log(await contract.balanceOf(user2.address));
            console.log(await contract.balanceOf(channel));
            console.log(await ethers.provider.getBalance(user1.address));
            console.log(await ethers.provider.getBalance(user2.address));
            // Increase
            console.log(">>> Increase");
            value = {
                channel: channel,
                index: await contract.connect(user2).channelIndexOf(channel),
                amount1: 300n,
                amount2: 700n,
                nonce: await contract.connect(user2).nonces(user2.address),
                deadline: (Math.floor(Date.now() / 1000) + 3600),
            };
            sign = await user2.signTypedData(domain, INCREASE_REQUEST_TYPES, value);
            request = {
                partner: user2.address,
                amount1: value.amount1,
                amount2: value.amount2,
                deadline: value.deadline,
                signature: sign,
            };
            result = await contract.connect(user1).verifyIncrease(request);
            console.log(result);
            await contract.connect(user1).increase(request);
            info = await contract.channelInfoOf(channel);
            console.log(info);
            console.log(await contract.balanceOf(user1.address));
            console.log(await contract.balanceOf(user2.address));
            console.log(await contract.balanceOf(channel));
            console.log(await ethers.provider.getBalance(user1.address));
            console.log(await ethers.provider.getBalance(user2.address));
            // Decrease
            console.log(">>> Decrease");
            value = {
                channel: channel,
                index: await contract.connect(user2).channelIndexOf(channel),
                amount1: 300n,
                amount2: 700n,
                nonce: await contract.connect(user2).nonces(user2.address),
                deadline: (Math.floor(Date.now() / 1000) + 3600),
            };
            sign = await user2.signTypedData(domain, DECREASE_REQUEST_TYPES, value);
            request = {
                partner: user2.address,
                amount1: value.amount1,
                amount2: value.amount2,
                deadline: value.deadline,
                signature: sign,
            };
            result = await contract.connect(user1).verifyDecrease(request);
            console.log(result);
            await contract.connect(user1).decrease(request);
            info = await contract.channelInfoOf(channel);
            console.log(info);
            console.log(await contract.balanceOf(user1.address));
            console.log(await contract.balanceOf(user2.address));
            console.log(await contract.balanceOf(channel));
            console.log(await ethers.provider.getBalance(user1.address));
            console.log(await ethers.provider.getBalance(user2.address));
            // Hold
            console.log(">>> Hold");
            let preImage = "0x1234567890123456789012345678901234567890123456789012345678901234";
            value = {
                channel: channel,
                index: await contract.connect(user2).channelIndexOf(channel),
                amount1: 10000n,
                amount2: 5000n,
                count: 1,
                lockterm: 3600 * 24 * 3,
                payHash: ethers.keccak256(preImage),
            };
            sign = await user2.signTypedData(domain, HOLD_REQUEST_TYPES, value);
            request = {
                partner: user2.address,
                amount1: value.amount1,
                amount2: value.amount2,
                count: value.count,
                lockterm: value.lockterm,
                preImage: preImage,
                signature: sign,
            };
            result = await contract.connect(user1).verifyHold(request);
            console.log(result);
            await contract.connect(user1).hold(request);
            info = await contract.channelInfoOf(channel);
            console.log(info);
            console.log(await contract.balanceOf(user1.address));
            console.log(await contract.balanceOf(user2.address));
            console.log(await contract.balanceOf(channel));
            console.log(await ethers.provider.getBalance(user1.address));
            console.log(await ethers.provider.getBalance(user2.address));
            // Close
            console.log(">>> Close");
            value = {
                channel: channel,
                index: await contract.connect(user2).channelIndexOf(channel),
                amount1: 14500n,
                amount2: 500n,
                nonce: await contract.connect(user2).nonces(user2.address),
                deadline: (Math.floor(Date.now() / 1000) + 3600),
            };
            sign = await user2.signTypedData(domain, CLOSE_REQUEST_TYPES, value);
            request = {
                partner: user2.address,
                amount1: value.amount1,
                amount2: value.amount2,
                deadline: value.deadline,
                signature: sign,
            };
            result = await contract.connect(user1).verifyClose(request);
            console.log(result);
            await contract.connect(user1).close(request);
            info = await contract.channelInfoOf(channel);
            console.log(info);
            console.log(await contract.balanceOf(user1.address));
            console.log(await contract.balanceOf(user2.address));
            console.log(await contract.balanceOf(channel));
            console.log(await ethers.provider.getBalance(user1.address));
            console.log(await ethers.provider.getBalance(user2.address));
            await contract.connect(user1).withdraw(ethers.parseEther("0.1"));
            await contract.connect(user2).withdraw(ethers.parseEther("0.1"));
            console.log(await contract.balanceOf(user1.address));
            console.log(await contract.balanceOf(user2.address));
            console.log(await contract.balanceOf(channel));
            console.log(await ethers.provider.getBalance(user1.address));
            console.log(await ethers.provider.getBalance(user2.address));
        });
    });
});
