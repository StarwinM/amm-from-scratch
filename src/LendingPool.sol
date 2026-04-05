// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MyToken.sol";

contract LendingPool {
    MyToken public collateralToken;
    MyToken public borrowToken;

    uint256 public constant LTV = 75; 
    uint256 public constant LIQUIDATION_THRESHOLD = 80; 
    uint256 public constant INTEREST_RATE_PER_SECOND = 3; 
    uint256 public constant RATE_PRECISION = 1e10;

    uint256 public collateralPrice = 1e18; 
    address public owner;

    struct Position {
        uint256 deposited;
        uint256 borrowed;
        uint256 lastUpdate;
    }

    mapping(address => Position) public positions;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount);
    event Repay(address indexed user, uint256 amount);
    event Liquidate(address indexed liquidator, address indexed user, uint256 debtRepaid, uint256 collateralSeized);

    constructor(address _collateralToken, address _borrowToken) {
        collateralToken = MyToken(_collateralToken);
        borrowToken = MyToken(_borrowToken);
        owner = msg.sender;
    }

    function setCollateralPrice(uint256 _price) external {
        require(msg.sender == owner, "Only owner");
        collateralPrice = _price;
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        collateralToken.transferFrom(msg.sender, address(this), amount);
        _accrueInterest(msg.sender);
        positions[msg.sender].deposited += amount;
        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        _accrueInterest(msg.sender);
        Position storage pos = positions[msg.sender];
        require(pos.deposited >= amount, "Insufficient collateral");

        uint256 newDeposited = pos.deposited - amount;
        if (pos.borrowed > 0) {
            uint256 hf = _healthFactor(newDeposited, pos.borrowed);
            require(hf > 1e18, "Health factor would drop below 1");
        }

        pos.deposited = newDeposited;
        collateralToken.transfer(msg.sender, amount);
        emit Withdraw(msg.sender, amount);
    }

    function borrow(uint256 amount) external {
        _accrueInterest(msg.sender);
        Position storage pos = positions[msg.sender];
        require(pos.deposited > 0, "No collateral deposited");

        uint256 collateralValue = (pos.deposited * collateralPrice) / 1e18;
        uint256 maxBorrow = (collateralValue * LTV) / 100;
        require(pos.borrowed + amount <= maxBorrow, "Exceeds LTV limit");

        pos.borrowed += amount;
        borrowToken.transfer(msg.sender, amount);
        emit Borrow(msg.sender, amount);
    }

    function repay(uint256 amount) external {
        _accrueInterest(msg.sender);
        Position storage pos = positions[msg.sender];
        require(pos.borrowed > 0, "Nothing to repay");

        uint256 repayAmount = amount > pos.borrowed ? pos.borrowed : amount;
        borrowToken.transferFrom(msg.sender, address(this), repayAmount);
        pos.borrowed -= repayAmount;
        emit Repay(msg.sender, repayAmount);
    }

    function liquidate(address user) external {
        _accrueInterest(user);
        Position storage pos = positions[user];
        require(pos.borrowed > 0, "No debt to liquidate");

        uint256 hf = _healthFactor(pos.deposited, pos.borrowed);
        require(hf < 1e18, "Position is healthy");

        uint256 debtToRepay = pos.borrowed;
        uint256 collateralToSeize = (debtToRepay * 1e18) / collateralPrice;

        // If collateral is not enough, seize all of it
        if (collateralToSeize > pos.deposited) {
            collateralToSeize = pos.deposited;
        }

        borrowToken.transferFrom(msg.sender, address(this), debtToRepay);
        pos.borrowed = 0;
        pos.deposited -= collateralToSeize;

        collateralToken.transfer(msg.sender, collateralToSeize);
        emit Liquidate(msg.sender, user, debtToRepay, collateralToSeize);
    }

    function getHealthFactor(address user) external view returns (uint256) {
        Position memory pos = positions[user];
        uint256 accruedDebt = pos.borrowed + _pendingInterest(pos);
        if (accruedDebt == 0) return type(uint256).max;
        return _healthFactor(pos.deposited, accruedDebt);
    }

    function getPosition(address user) external view returns (uint256 deposited, uint256 borrowed) {
        Position memory pos = positions[user];
        deposited = pos.deposited;
        borrowed = pos.borrowed + _pendingInterest(pos);
    }

    function _accrueInterest(address user) internal {
        Position storage pos = positions[user];
        if (pos.borrowed > 0 && pos.lastUpdate > 0) {
            uint256 interest = _pendingInterest(pos);
            pos.borrowed += interest;
        }
        pos.lastUpdate = block.timestamp;
    }

    function _pendingInterest(Position memory pos) internal view returns (uint256) {
        if (pos.borrowed == 0 || pos.lastUpdate == 0) return 0;
        uint256 timeElapsed = block.timestamp - pos.lastUpdate;
        return (pos.borrowed * INTEREST_RATE_PER_SECOND * timeElapsed) / RATE_PRECISION;
    }

    function _healthFactor(uint256 deposited, uint256 borrowed) internal view returns (uint256) {
        if (borrowed == 0) return type(uint256).max;
        uint256 collateralValue = (deposited * collateralPrice) / 1e18;
        uint256 liquidationValue = (collateralValue * LIQUIDATION_THRESHOLD) / 100;
        return (liquidationValue * 1e18) / borrowed;
    }
}
