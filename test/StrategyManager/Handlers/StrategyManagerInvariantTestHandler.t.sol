pragma solidity ^0.8.20;

import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {stdMath} from "forge-std/StdMath.sol";

import {IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {HoldingManager} from "../../../src/HoldingManager.sol";
import {SharesRegistry} from "../../../src/SharesRegistry.sol";
import {StrategyManager} from "../../../src/StrategyManager.sol";
import {StrategyWithRewardsYieldsMock} from "../../utils/mocks/StrategyWithRewardsYieldsMock.sol";

contract StrategyManagerInvariantTestHandler is CommonBase, StdCheats, StdUtils {
    using stdMath for int256;

    HoldingManager internal holdingManager;
    StrategyManager internal strategyManager;
    SharesRegistry internal sharesRegistry;
    StrategyWithRewardsYieldsMock internal strategy;

    uint256 private minInvestAmount = 1e18;

    address internal collateralToken;
    mapping(address => uint256) internal collateralDeposited;

    mapping(address => address) internal userHolding;
    address[] public USER_ADDRESSES = [
        address(uint160(uint256(keccak256("user1")))),
        address(uint160(uint256(keccak256("user2")))),
        address(uint160(uint256(keccak256("user3")))),
        address(uint160(uint256(keccak256("user4")))),
        address(uint160(uint256(keccak256("user5"))))
    ];

    constructor(
        StrategyWithRewardsYieldsMock _strategy,
        HoldingManager _holdingManager,
        StrategyManager _strategyManager,
        SharesRegistry _sharesRegistry,
        address _collateralToken
    ) {
        strategy = _strategy;
        holdingManager = _holdingManager;
        strategyManager = _strategyManager;
        sharesRegistry = _sharesRegistry;
        collateralToken = _collateralToken;
        createUserHoldings();
    }

    function user_invest(uint256 _mintAmount, uint256 user_idx) external {
        _mintAmount = bound(_mintAmount, minInvestAmount, 100_000e18);
        address user = pickUpUser(user_idx);

        IERC20Metadata collateralContract = IERC20Metadata(collateralToken);

        uint256 collateralAmount = _mintAmount * 2;

        //get tokens for user
        deal(collateralToken, user, collateralAmount);

        // make deposit to the holding
        vm.startPrank(user, user);
        collateralContract.approve(address(holdingManager), collateralAmount);
        holdingManager.deposit(collateralToken, collateralAmount);
        // make invest to the strategy
        strategyManager.invest(collateralToken, address(strategy), _mintAmount, 0, bytes(""));
        vm.stopPrank();

        collateralDeposited[user] += collateralAmount;
    }

    function user_claim_invested(uint256 _claimAmount, uint256 user_idx) external {
        address user = pickUpUser(user_idx);

        vm.startPrank(user, user);
        (, uint256 shares) = strategy.recipients(userHolding[user]);

        // check if user has enough shares to claim
        vm.assume(shares >= minInvestAmount);
        _claimAmount = bound(_claimAmount, minInvestAmount, shares);
        
        // claim investment
        strategyManager.claimInvestment(userHolding[user], collateralToken, address(strategy), _claimAmount, "");
        vm.stopPrank();

        // if yieldAmount in strategy is positive, it expected to be added to the user's collateral, otherwise - subtracted
        if(strategy.yieldAmount() > 0) {
            collateralDeposited[user] += strategy.yieldAmount().abs();
        }
        else {
            collateralDeposited[user] -= strategy.yieldAmount().abs();
        }
    }

    function set_strategy_yield(int256 _amount) external {
        // set yield amount bellow minInvestAmount to avoid arithmetic overflow in withdraw
        vm.assume(_amount.abs() < minInvestAmount);
        strategy.setYield(_amount);
    }

    function getTotalCollateral() external view returns (uint256 totalCollateral) {
        totalCollateral = 0;
        for (uint256 i = 0; i < USER_ADDRESSES.length; i++) {
            totalCollateral += collateralDeposited[USER_ADDRESSES[i]];
        }
    }

    function getTotalCollateralFromRegistry() external view returns (uint256 totalCollateralFromRegistry) {
        totalCollateralFromRegistry = 0;
        for (uint256 i = 0; i < USER_ADDRESSES.length; i++) {
            totalCollateralFromRegistry += sharesRegistry.collateral(userHolding[USER_ADDRESSES[i]]);
        }
    }

    function createUserHoldings() private {
        for (uint256 i = 0; i < USER_ADDRESSES.length; i++) {
            address user = USER_ADDRESSES[i];
            vm.startPrank(user, user);
            userHolding[user] = holdingManager.createHolding();
            vm.stopPrank();
        }
    }

    function pickUpUser(uint256 _user_idx) public view returns (address) {
        _user_idx = _user_idx % USER_ADDRESSES.length;
        return USER_ADDRESSES[_user_idx];
    }
}
