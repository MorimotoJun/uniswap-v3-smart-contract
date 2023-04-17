import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
import { ContractEnum } from "../scripts/utils";

describe("SimpleSwap", function () {
    describe("Deployment", function () {
        it("Should set the right unlockTime", async function () {
            const { swap } = await loadFixture(deploySwap);

            expect(await swap.swapRouter()).to.equal('0xE592427A0AEce92De3Edee1F18E0157C05861564');
            expect(await swap.quoter()).to.equal('0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6');
            expect(await swap.wmatic()).to.equal('0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270');
        });
    });

    describe("swapMaticToDai", function () {
        it("Should set the right unlockTime", async function () {
            const { swap } = await loadFixture(deploySwap);

            await swap.swapMaticToTbs()

            expect(await swap.swapRouter()).to.equal('0xE592427A0AEce92De3Edee1F18E0157C05861564');
            expect(await swap.quoter()).to.equal('0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6');
            expect(await swap.wmatic()).to.equal('0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270');
        });
    });
});


async function deploySwap() {
    const Swap = await ethers.getContractFactory(ContractEnum.Swap);
    const swap = await Swap.deploy();

    return { swap };
}