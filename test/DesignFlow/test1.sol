// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../../src/contracts/base/PotPool.sol";


// These comments are only for quick test execution
// onlyGovernance
// In this function, pushAllRewards is commented out

// In this function getAllRewards
// 📌 The second condition is commented out because it prolongs the test and has no effect on the function's behavior
// bool rewardPayout = (!smartContractStakers[msg.sender] /* || !IController(controller()).greyList(msg.sender)*/);



contract LPToken {
    string public name = "LPToken";
    string public symbol = "LP";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(uint256 _initialSupply) {
        totalSupply = _initialSupply;
        balanceOf[msg.sender] = _initialSupply;
        emit Transfer(address(0), msg.sender, _initialSupply);
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        require(balanceOf[msg.sender] >= _value, "Insufficient balance");
        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(balanceOf[_from] >= _value, "Insufficient balance");
        require(allowance[_from][msg.sender] >= _value, "Allowance exceeded");
        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        allowance[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return true;
    }
}


contract RewardToken {
    string public name = "RewardToken";
    string public symbol = "rw";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(uint256 _initialSupply) {
        totalSupply = _initialSupply;
        balanceOf[msg.sender] = _initialSupply;
        emit Transfer(address(0), msg.sender, _initialSupply);
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        require(balanceOf[msg.sender] >= _value, "Insufficient balance");
        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(balanceOf[_from] >= _value, "Insufficient balance");
        require(allowance[_from][msg.sender] >= _value, "Allowance exceeded");
        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        allowance[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return true;
    }
}


contract DesignFlow is Test {
    PotPool pool;

    LPToken LP;

    RewardToken DAI;
    RewardToken USDC;
    RewardToken USDT;

    address rewardDistribution=address(0x088888);

    address user=address(0x00005522);

    function setUp() public {
        LP=new LPToken(1000*1e18);


        DAI= new RewardToken(10000*1e18);
        USDC= new RewardToken(10000*1e18);
        USDT= new RewardToken(10000*1e18);

        
        address[] memory _rewardTokens=new address[](3);
        _rewardTokens[0]=address(DAI);
        _rewardTokens[1]=address(USDC);
        _rewardTokens[2]=address(USDT);


        address[] memory _rewardDistribution=new address[](1);
        _rewardDistribution[0]=rewardDistribution;

        // ساخت استخر
        pool=new PotPool(
        _rewardTokens,
        address(LP),
        864000,
        _rewardDistribution,
        address(0x000123),
        "LPToken",
        "LP",
        18
        );


        ///@notice No tokens are sent to the protocol here for rewards, so the protocol has no tokens to distribute
        DAI.transfer(address(pool),1*1e18);
        DAI.approve(address(pool),1*1e18);

        USDC.transfer(address(pool),1*1e18);
        USDC.approve(address(pool),1*1e18);
        
        USDT.transfer(address(pool),1*1e18);
        USDT.approve(address(pool),1*1e18);


        //rewards
        vm.startPrank(rewardDistribution);
        pool.notifyTargetRewardAmount(address(DAI),5000*1e18);
        pool.notifyTargetRewardAmount(address(USDC),5000*1e18);
        pool.notifyTargetRewardAmount(address(USDT),5000*1e18);

        vm.stopPrank();
        LP.transfer(user,500*1e18);
        vm.prank(user);
        LP.approve(address(pool),500*1e18);

    }

    ///@notice In both tests, no transfer occurs due to lack of reward tokens in the protocol, but the transaction executes without any feedback
    // getAllRewards() function 
    function test_getAllRewards() public {

        vm.prank(user);
        pool.stake(500*1e18);

        //please waiting ...
        vm.warp(block.timestamp+864000);//~10 days 

        vm.prank(user);
        pool.getAllRewards();

    }

    //pushAllRewards() fucntion 
    function test_pushAllRewards() public {
        vm.prank(user);
        pool.stake(500*1e18);

        //please waiting ...
        vm.warp(block.timestamp+864000);//~10 days 

        vm.prank(user);
        pool.pushAllRewards(user);

    }
}




