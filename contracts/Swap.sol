// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;
pragma abicoder v2;

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@uniswap/v3-core/contracts/libraries/FullMath.sol';
import '@uniswap/v3-core/contracts/libraries/SqrtPriceMath.sol';
import '@uniswap/v3-core/contracts/libraries/FixedPoint96.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

enum FeeTier {
    Low, Mid, High
}

interface IWmatic is IERC20 {
    function deposit() payable external;
    function withdraw(uint wad) payable external;
}

contract SimpleSwap {
    using SafeMath for uint256;

    ISwapRouter public immutable swapRouter;
    IQuoter public immutable quoter;
    IUniswapV3Pool public immutable pool;
    IWmatic public immutable wmatic;

    address public constant TBS = 0x5A7BB7B8EFF493625A2bB855445911e63A490E42;
    address public constant WMATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;

    address private constant ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address private constant QUOTER = 0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6;
    address private constant POOL   = 0xf0359086773adbec24ea18a9ce697f45d1a19fbe;
    
    constructor() {
        swapRouter = ISwapRouter(ROUTER);
        quoter = IQuoter(QUOTER);
        pool = IUniswapV3Pool(POOL);
        wmatic = IWmatic(WMATIC);
    }

    function calculateSqrtPriceLimitX96() public pure returns (uint160 sqrtPriceLimitX96) {
        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
        // numerator = sqrtPriceX96 * sqrtPriceX96 / 2^96
        uint256 priceA = (uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) >> 96;
        // denominator = 2^96
        uint256 priceB = 1 << 96;

        uint256 price = priceA.mul(FixedPoint96.Q96).div(priceB);
        sqrtPriceLimitX96 = SqrtPriceMath.getNextSqrtPriceFromInput(priceA.mul(FixedPoint96.Q96).div(priceB));
    }
    
    function swapMaticToTbs(uint160 priceLimit, FeeTier feeTier) external payable returns (uint256 amountOut) {

        uint256 amountIn = msg.value;

        // // Transfer the specified amount of WMATIC to this contract.
        // TransferHelper.safeTransferFrom(WMATIC, msg.sender, address(this), amountIn);
        wmatic.deposit{ value: msg.value }();
        // Approve the router to spend WMATIC.
        TransferHelper.safeApprove(WMATIC, address(swapRouter), amountIn);
        
        // Set fee amount
        uint24 fee = 0;
        if (feeTier == FeeTier.Low) { fee = 3000; }
        else if (feeTier == FeeTier.Mid) { fee = 5000; }
        if (feeTier == FeeTier.High) { fee = 10000; }

        uint256 quotedAmountOut = quoter.quoteExactInputSingle(
            WMATIC,
            TBS,
            fee,
            amountIn,
            priceLimit
        );

        // Create the params that will be used to execute the swap
        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: WMATIC,
                tokenOut: TBS,
                fee: fee,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: quotedAmountOut,
                sqrtPriceLimitX96: priceLimit
            });
        // The call to `exactInputSingle` executes the swap.
        amountOut = swapRouter.exactInputSingle(params);
    }

    function swapTbsToMatic(uint256 amountIn, uint160 priceLimit, FeeTier feeTier) external returns (uint256 amountOut) {

        // // Transfer the specified amount of TBS to this contract.
        TransferHelper.safeTransferFrom(TBS, msg.sender, address(this), amountIn);
        // Approve the router to spend TBS.
        TransferHelper.safeApprove(TBS, address(swapRouter), amountIn);
        
        // Set fee amount
        uint24 fee = 0;
        if (feeTier == FeeTier.Low) { fee = 3000; }
        else if (feeTier == FeeTier.Mid) { fee = 5000; }
        if (feeTier == FeeTier.High) { fee = 10000; }

        uint256 quotedAmountOut = quoter.quoteExactInputSingle(
            TBS,
            WMATIC,
            fee,
            amountIn,
            priceLimit
        );

        // Create the params that will be used to execute the swap
        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: TBS,
                tokenOut: WMATIC,
                fee: fee,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: quotedAmountOut,
                sqrtPriceLimitX96: priceLimit
            });
        // The call to `exactInputSingle` executes the swap.
        amountOut = swapRouter.exactInputSingle(params);

        wmatic.withdraw(amountOut);
        msg.sender.transfer(amountOut);
    }
}