// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;
pragma abicoder v2;

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@uniswap/v3-core/contracts/libraries/FullMath.sol';
import '@uniswap/v3-core/contracts/libraries/SqrtPriceMath.sol';
import '@uniswap/v3-core/contracts/libraries/FixedPoint96.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';

import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/interfaces/IQuoterV2.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "hardhat/console.sol";

enum FeeTier {
    Low, Mid, High
}

struct SwapRequest {
    address token0;
    address token1;
    uint256 amountIn;
    FeeTier feeTier;
}

interface IWmatic is IERC20 {
    function deposit() payable external;
    function withdraw(uint wad) payable external;
}


/****************************************************
 * @dev Swap contrtact using the (MATIC-ERC20) pair *
 * @dev Using UniswapV3
 ****************************************************/

contract SimpleSwap {
    using SafeMath for uint256;

    ISwapRouter public immutable swapRouter;
    IQuoterV2 public immutable quoter;
    IUniswapV3Factory public immutable factory;
    IWmatic public immutable wmatic;

    address public constant WMATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    address private constant ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address private constant QUOTER = 0x61fFE014bA17989E743c5F6cB21bF9697530B21e;
    address private constant FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    
    constructor() {
        swapRouter = ISwapRouter(ROUTER);
        quoter = IQuoterV2(QUOTER);
        factory = IUniswapV3Factory(FACTORY);
        wmatic = IWmatic(WMATIC);
    }

    function _getFee(FeeTier feeTier) private pure returns (uint24 fee) {
        if (feeTier == FeeTier.Low) { fee = 3000; }
        else if (feeTier == FeeTier.Mid) { fee = 5000; }
        else { fee = 10000; }
    }

    function _getPool(address token0, address token1, uint24 fee) private view returns (address pool) {
        pool = factory.getPool(token0, token1, fee);
    }

    function _calculateSqrtPriceLimitX96(bool zeroToOne, uint256 amountIn, IUniswapV3Pool pool) private view returns (uint160 sqrtPriceLimitX96) {
        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
        // numerator = sqrtPriceX96 * sqrtPriceX96 / 2^96
        uint256 priceA = (uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) >> 96;
        // denominator = 2^96
        uint256 priceB = 1 << 96;

        uint256 price = priceA.mul(FixedPoint96.Q96).div(priceB);
        console.log(price);
        console.log(zeroToOne);
        console.log(amountIn);
        console.log(pool.liquidity());
        sqrtPriceLimitX96 = SqrtPriceMath.getNextSqrtPriceFromInput(
            uint160(price),
            pool.liquidity(),
            amountIn,
            zeroToOne
        );
    }
    
    function swapMaticToToken(SwapRequest memory _swapRequest) external payable returns (uint256 amountOut) {
        require(
            _swapRequest.amountIn == msg.value && msg.value > 0, 
            "invalid amountIn"
        );

        uint256 amountIn = msg.value;
        bool zeroToOne = false;
        address token = address(0);
        if (_swapRequest.token0 == WMATIC) {
            zeroToOne = true;
            token = _swapRequest.token1;
        }
        else { token = _swapRequest.token0; }

        // Get Wrapped MATIC
        wmatic.deposit{ value: msg.value }();
        // Approve the router to spend WMATIC.
        TransferHelper.safeApprove(WMATIC, address(swapRouter), amountIn);

        // Set fee amount
        uint24 fee = _getFee(_swapRequest.feeTier);

        IUniswapV3Pool pool = IUniswapV3Pool(_getPool(_swapRequest.token0, _swapRequest.token1, fee));

        uint160 priceLimit = _calculateSqrtPriceLimitX96(zeroToOne, amountIn, pool);

        (uint256 quotedAmountOut,,,) = quoter.quoteExactInputSingle(IQuoterV2.QuoteExactInputSingleParams(
            WMATIC,
            token,
            amountIn,
            fee,
            priceLimit
        ));

        // Create the params that will be used to execute the swap
        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: WMATIC,
                tokenOut: token,
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

    function swapTokenToMatic(SwapRequest memory _swapRequest) external returns (uint256 amountOut) {
        uint256 amountIn = _swapRequest.amountIn;

        bool zeroToOne = true;
        address token = address(0);
        if (_swapRequest.token0 == WMATIC) {
            zeroToOne = false;
            token = _swapRequest.token1;
        }
        else { token = _swapRequest.token0; }

        // // Transfer the specified amount of TBS to this contract.
        TransferHelper.safeTransferFrom(token, msg.sender, address(this), amountIn);
        // Approve the router to spend TBS.
        TransferHelper.safeApprove(token, address(swapRouter), amountIn);

        // Set fee amount
        uint24 fee = _getFee(_swapRequest.feeTier);

        // IUniswapV3Pool pool = IUniswapV3Pool(0xB68606a75b117906e06cAa0755896AD2b3Dd0272);
        IUniswapV3Pool pool = IUniswapV3Pool(_getPool(_swapRequest.token0, _swapRequest.token1, fee));

        console.log(
            address(pool)
        );

        uint160 priceLimit = _calculateSqrtPriceLimitX96(zeroToOne, amountIn, pool);

        console.log(address(token));
        console.log(WMATIC);
        console.log(fee);
        console.log(amountIn);
        console.log(priceLimit);

        (uint256 quotedAmountOut,,,) = quoter.quoteExactInputSingle(IQuoterV2.QuoteExactInputSingleParams(
            token,
            WMATIC,
            amountIn,
            fee,
            priceLimit
        ));

        console.log(
            quotedAmountOut
        );

        // Create the params that will be used to execute the swap
        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: token,
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