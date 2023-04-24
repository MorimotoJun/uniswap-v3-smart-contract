import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { ContractEnum, getTokenABI } from "../scripts/utils";

enum FeeTier {
    LOW  = 0,
    MID  = 1,
    HIGH = 2
}

enum ZeroOrOne {
    Zero, One,
}

interface SwapRequest {
    token0:   string;
    token1:   string;
    amountIn: string;
    feeTier: FeeTier;
}

const WMATIC = '0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270';
const TOKEN = '0x5A7BB7B8EFF493625A2bB855445911e63A490E42';
// const TOKEN = '0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063';

let balance = '0';

describe("SimpleSwap", function () {
    describe("Deployment", function () {
        it("Should seploy contract successfully", async function () {
            const { swap } = await loadFixture(deploySwap);

            expect(await swap.swapRouter()).to.equal('0xE592427A0AEce92De3Edee1F18E0157C05861564');
            expect(await swap.quoter()).to.equal('0x61fFE014bA17989E743c5F6cB21bF9697530B21e');
            expect(await swap.wmatic()).to.equal('0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270');
        });
    });

    describe("swapMaticToToken", function () {
        it("Should swap matic to Token", async function () {
            const { swap, wmatic, token } = await loadFixture(deploySwap);
            const [ user ] = await ethers.getSigners();

            balance = (await user.getBalance()).toString();

            const req: SwapRequest = {
                token0: WMATIC,
                token1: TOKEN,
                amountIn: ethers.utils.parseEther('10').toString(),
                feeTier: FeeTier.LOW,
            }

            await swap.swapMaticToToken(req, {
                value: ethers.utils.parseEther('10'),
                gasLimit: 500000
            });

            expect(BigInt(balance) - BigInt((await user.getBalance()).toString())).to.greaterThan(BigInt('10000000000000000000'));
            expect(await token.balanceOf(user.address)).to.greaterThan('0');
            expect(await wmatic.balanceOf(user.address)).to.equal('0');

            balance = (await user.getBalance()).toString();
        });

        it('Should be rejected by invalid amountIn', async function() {
            const { swap, wmatic, token } = await loadFixture(deploySwap);
            const [ user ] = await ethers.getSigners();

            let req: SwapRequest = {
                token0: WMATIC,
                token1: TOKEN,
                amountIn: ethers.utils.parseEther('0').toString(),
                feeTier: FeeTier.LOW,
            }

            let e = 'no error';
            try {
                await swap.swapMaticToToken(req, {
                    value: ethers.utils.parseEther('0'),
                    gasLimit: 500000
                });
            } catch (err: any) {
                e = err.message;
            }

            expect(e).to.include('invalid amountIn');

            req = {
                token0: WMATIC,
                token1: TOKEN,
                amountIn: ethers.utils.parseEther('10').toString(),
                feeTier: FeeTier.LOW,
            }
            e = 'no error';

            try {
                await swap.swapMaticToToken(req, {
                    value: ethers.utils.parseEther('30'),
                    gasLimit: 500000
                });
            } catch (err: any) {
                e = err.message;
            }

            expect(e).to.include('invalid amountIn');
        })
    });

    describe('swapTokenToMatic', function() {
        it('Should swap successfully', async function() {
            const { swap, wmatic, token } = await loadFixture(deploySwap);
            const [ user ] = await ethers.getSigners();

            let req: SwapRequest = {
                token0: WMATIC,
                token1: TOKEN,
                amountIn: ethers.utils.parseEther('10').toString(),
                feeTier: FeeTier.LOW,
            }

            await swap.swapMaticToToken(req, {
                value: ethers.utils.parseEther('10'),
                gasLimit: 500000
            });

            balance = (await user.getBalance()).toString();
            const amountIn = await token.balanceOf(user.address);

            console.log(amountIn.toString())

            await token.approve(swap.address, amountIn);
            
            req = {
                token0: WMATIC,
                token1: TOKEN,
                amountIn,
                feeTier: FeeTier.LOW,
            }

            await swap.swapTokenToMatic(req, {
                gasLimit: 500000
            });

            expect(BigInt((await user.getBalance()).toString()) - BigInt(balance)).to.lessThan(BigInt('10000000000000000000'));
            expect(BigInt((await user.getBalance()).toString()) - BigInt(balance)).to.greaterThan(BigInt('9000000000000000000'));
            expect(await token.balanceOf(user.address)).to.equal('0');
            expect(await wmatic.balanceOf(user.address)).to.equal('0');

            balance = (await user.getBalance()).toString();
        })
    })
});

async function deploySwap() {
    const Swap = await ethers.getContractFactory(ContractEnum.Swap);
    const swap = await Swap.deploy();

    const [user] = await ethers.getSigners();
    const token = new ethers.Contract(TOKEN, getTokenABI(), user);
    const wmatic = new ethers.Contract(WMATIC, getTokenABI(), user);

    return { swap, token, wmatic };
}