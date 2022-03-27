//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";

interface IUniswapRouter is ISwapRouter {
    function refundETH() external payable;
}

contract HodlBank is Ownable {
    struct StrategyRatio {
        address token;
        uint256 ratio;
        uint256 value;
    }

    struct Strategy {
        address owner;
        string name;
        uint256 strategyId;
        uint256 createdOn;
        uint256 dueOn; 
        uint256 initialAmount;
        bool active;
        StrategyRatio[] ratios;
    }

    IUniswapRouter public constant uniswapRouter = IUniswapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IQuoter public constant quoter = IQuoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);
    address private constant WETH9 = 0xc778417E063141139Fce010982780140Aa0cD5Ab;

    mapping(uint256 => Strategy) public strategies;
    mapping(address => uint256[]) public ownerToStrategy;
    mapping(uint256 => address) public strategyToOwner;
    mapping(address => bool) public isAllowedToken;

    address[] public allowedTokens;
    address public hbnkToken;

    uint256 numStrategies;

    modifier onlyStrategyOwner(uint256 _strategyId) {
        require(strategyToOwner[_strategyId] == msg.sender, "only strategy owner can fund");
        _;
    }

    event StrategyDeployed(uint256 _strategyId, address strategyOwner);
    event StrategyWithdrawal(uint256 _strategyId, address strategyOwner);

    constructor(address[] memory _allowedTokens) {
        require(_allowedTokens.length > 0, "allowed tokens is zero");

        allowedTokens = _allowedTokens;
        for(uint256 i = 0; i < _allowedTokens.length; i++) {
            isAllowedToken[_allowedTokens[i]] = true;
        }
    }

    function deployStrategy(string memory _name, StrategyRatio[] memory _ratios, uint256 _depositTime) external payable returns(uint256 strategyId) {
        require(_depositTime > 0, "deposit time must be positive");
        require(checkStrategyRatios(_ratios), "ratios need to equal 100");
        require(checkStrategyTokensAllowed(_ratios), "strat contains not allowed token");

        strategyId = numStrategies++;

        Strategy storage s = strategies[strategyId];
        s.owner = msg.sender;
        s.strategyId = strategyId;
        s.name = _name;
        s.createdOn = block.timestamp;
        s.dueOn = block.timestamp + _depositTime;
        s.initialAmount = msg.value;
        s.active = true;

        for(uint256 i = 0; i < _ratios.length; i++) {
            StrategyRatio memory ratio = _ratios[i];

            uint256 amt = mulDiv(msg.value, ratio.ratio, 100);
            uint256 amountOut = swapExactEthToToken(ratio.token, amt);
            ratio.value = amountOut;

            s.ratios.push(ratio);
        }
        console.log("contract value", address(this).balance);

        ownerToStrategy[msg.sender].push(strategyId);
        strategyToOwner[strategyId] = msg.sender;

        emit StrategyDeployed(strategyId, msg.sender);
    }

    function swapExactEthToToken(address _token, uint256 _amount) internal returns(uint256 _amountOut){
        require(msg.value > 0, "Must pass non 0 ETH amount");

        uint256 deadline = block.timestamp + 15;
        address tokenIn = WETH9;
        uint24 fee = 3000;
        uint256 amountOutMinimum = 1;
        uint160 sqrtPriceLimitX96 = 0;
        
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams(
            tokenIn,
            _token,
            fee,
            address(this),
            deadline,
            _amount,
            amountOutMinimum,
            sqrtPriceLimitX96
        );
        _amountOut = uniswapRouter.exactInputSingle{ value: _amount }(params);
    }

    function getStrategies() external view returns(Strategy[] memory) {
        Strategy[] memory _strategies = new Strategy[](ownerToStrategy[msg.sender].length);

        for(uint256 i = 0; i < ownerToStrategy[msg.sender].length; i++) {
            console.log(ownerToStrategy[msg.sender][i]);
            Strategy storage strategy = strategies[ownerToStrategy[msg.sender][i]];
            if(strategy.active == true) {
                _strategies[i] = strategy;
            }
        }
        return _strategies;
    }

    function withdrawStrategy(uint256 _strategyId) external onlyStrategyOwner(_strategyId) {
        Strategy storage strategy = strategies[_strategyId];
        
        bool isDue = (strategy.dueOn <= block.timestamp);
        bool success;
        console.log("is due", isDue);
        removeStrategy(_strategyId);

        if(isDue == true) {
            payReward(strategy.createdOn, strategy.dueOn);
        }

        for(uint256 i = 0; i < strategy.ratios.length; i++) {
            StrategyRatio memory ratio = strategy.ratios[i];
            console.log(ratio.token, ratio.value);

            uint256 value = ratio.value;
            if(!isDue) {
                value = ratio.value / 2;
            }

            require(IERC20(ratio.token).balanceOf(address(this)) >= value, "insuff funds");
            success = IERC20(ratio.token).transfer(strategy.owner, value);
            require(success, "transfer failed");
        }
        emit StrategyWithdrawal(_strategyId, strategy.owner);
    }

    function removeStrategy(uint256 _strategyId) internal onlyStrategyOwner(_strategyId) { 
        strategies[_strategyId].active = false;
        
        if(ownerToStrategy[msg.sender].length == 1) {
            delete ownerToStrategy[msg.sender];
        } else {
            for(uint256 i; i < ownerToStrategy[msg.sender].length; i++) {
                if(ownerToStrategy[msg.sender][i] == _strategyId) {
                    delete ownerToStrategy[msg.sender][i];
                    break;
                }
            }
        }
        
        delete strategyToOwner[_strategyId];
    } 

    function calculateReward(uint256 _createdOn, uint256 _dueOn) internal view returns(uint256 reward) {
        require(_dueOn > _createdOn, "timestamp error");
        
        reward = mulDiv((_dueOn - _createdOn), 1, 86400) * (10 ** 18) ;
        console.log("reward", reward);
    }
    function payReward(uint256 _createdOn, uint256 _dueOn) internal returns(bool success) {
        uint256 reward = calculateReward(_createdOn, _dueOn);
        console.log(IERC20(hbnkToken).balanceOf(address(this)));
        require(IERC20(hbnkToken).balanceOf(address(this)) >= reward, "insuff funds");
        success = IERC20(hbnkToken).transfer(msg.sender, reward);
    } 

    function checkStrategyRatios(StrategyRatio[] memory _ratios) internal pure returns(bool) {
        require(_ratios.length > 0, "ratios length is 0");
        uint256 ratioSum;
        for(uint256 i = 0; i < _ratios.length; i++) {
            ratioSum += _ratios[i].ratio;
        }
        return (ratioSum == 100);
    }

    function checkStrategyTokensAllowed(StrategyRatio[] memory _ratios) internal view returns(bool) {
        require(_ratios.length > 0, "ratios length is 0");
        for(uint256 i = 0; i < _ratios.length; i++) {
            if(isAllowedToken[_ratios[i].token] == false) {
                return false;
            }
        }        
        return true;
    }

    function addAllowedToken(address _tokenAddr) external onlyOwner {
        allowedTokens.push(_tokenAddr);
    }

    function getAllowedTokens() external view returns(address[] memory) {
        return allowedTokens;
    }

    function setHbnkTokenAddress(address _tokenAddress) external onlyOwner {
        hbnkToken = _tokenAddress;
    }

    function mulDiv (uint x, uint y, uint z) public pure returns (uint)
    {
        if(y == z) return x;
        
        uint a = x / z; uint b = x % z; // x = a * z + b
        uint c = y / z; uint d = y % z; // y = c * z + d
        return a * b * z + a * d + b * c + b * d / z;
    }
}
