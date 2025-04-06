// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./library/ABDKMath64x64.sol";

contract MatchP is OwnableUpgradeable, UUPSUpgradeable {
    using ABDKMath64x64 for int128;

    address public token;
    uint256 public feeRate; // 抽成比例点数
    uint256 public feeDecimals; // 抽成比例分母
    address public MatchProtocol; // 协议收取match代币地址
    uint256 public _nonce; // 游戏ID计数器，从0开始
    mapping(uint256 => game) public games; // 改为mapping
    uint256 public totalVoteScore;
    uint256 public startAppend; // limit start time
    uint256 public endAppend; //  limit end time

    // 标记是否是参赛者
    mapping(uint256 => mapping(address => bool)) public isPlayer;
    // 赛事某个用户接受的质押总额
    mapping(uint256 => mapping(address => uint256)) public playerStakeBalance;
    // 用户在某个赛事对某个玩家的质押信息
    mapping(address => mapping(uint256 => stakeInfo)) public voterGameStake;
    // 创建赛事的白名单
    mapping(address => bool) public whiteList;
    // 是否领取了match和积分
    mapping(address => bool) public isGain;
    mapping(address => uint256) public voteScores;
    // 参赛者列表
    mapping(uint256 => address[]) public Aplayers;
    // 质押/投票者列表
    mapping(uint256 => address[]) public Avoters;

    struct stakeInfo {
        uint256 gameId;
        address player;
        uint256 stakeAmount;
    }

    struct game {
        string name;
        uint256 id;
        uint256 startTime;
        uint256 endTime;
        uint8 exist; // 1: 存在, 0: 不存在
        uint8 isSettled; // 1: 已结算, 0: 未结算
        uint256 averageScore;
    }

    enum ScoreType {
        Technical,
        Business,
        Completeness,
        Innovation
    }

    event CreateGame(
        uint256 indexed gameId,
        string indexed _name,
        uint256 startTime,
        uint256 endTime,
        address builder
    );
    event JoinGame(uint256 gameId, address player);
    event Settle(
        uint256 gameId,
        address winnerVoter,
        uint256 _time,
        uint256 _bonus
    );
    event Settled(uint256 gameId, address winner, uint256 _time);
    event DoNothing(address indexed sender);

    error GameAlreadyOver();

    modifier checkAuthority() {
        require(
            whiteList[msg.sender] || msg.sender == owner(),
            "not in white list"
        );
        _;
    }

    modifier limitStake(uint256 _gameId, address _player) {
        require(!isPlayer[_gameId][_player], "player can't stake");
        _;
    }

    modifier IsSettled(uint256 _gameId) {
        require(games[_gameId].isSettled == 0, "game is settled");
        _;
    }

    function initialize(
        address _token,
        address protocol,
        uint256 st,
        uint256 et
    ) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        token = _token;
        _nonce = 1; // 从0开始
        totalVoteScore = 10000;
        feeRate = 10;
        feeDecimals = 10 ** 2;
        startAppend = st;
        endAppend = et;
        MatchProtocol = protocol;
    }

    function createGame(
        string memory _name,
        uint256 _startTime,
        uint256 _endTime
    ) public returns (uint256) {
        require(
            _startTime > block.timestamp + startAppend,
            "Start time must be in the future"
        );
        require(
            _endTime > _startTime + endAppend,
            "End time must be at least endAppend after start"
        );
        uint256 gameId = _nonce;
        games[gameId] = game(_name, gameId, _startTime, _endTime, 1, 0, 0);

        _nonce++;
        emit CreateGame(gameId, "New Game", _startTime, _endTime, msg.sender);
        return gameId;
    }

    function getToken() public returns (bool) {
        require(msg.sender != address(0), "token is zero");
        require(!isGain[msg.sender], "already gained");
        // IERC20(token).transfer(msg.sender, 30);
        require(_getToken(msg.sender), "get token fail");
        totalVoteScore -= 30;
        voteScores[msg.sender] = 30;
        isGain[msg.sender] = true;
        return true;
    }

    function _getToken(address to) internal returns (bool) {
        IERC20(token).transfer(to, 30);
        return true;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function stake(
        uint256 _gameId,
        address _player,
        uint256 amount
    ) public limitStake(_gameId, msg.sender) returns (bool) {
        require(games[_gameId].exist == 1, "game does not exist");
        require(
            block.timestamp < games[_gameId].startTime,
            "invalid bet period"
        );
        require(isPlayer[_gameId][_player], "invalid target player");
        require(
            IERC20(token).allowance(msg.sender, address(this)) >= amount &&
                amount >= 10,
            "invalid Match token stake balance"
        );

        uint256 _fee = (amount * feeRate) / feeDecimals;
        IERC20(token).transferFrom(msg.sender, MatchProtocol, _fee);
        IERC20(token).transferFrom(msg.sender, address(this), amount - _fee);

        playerStakeBalance[_gameId][_player] += amount - _fee;
        voterGameStake[msg.sender][_gameId] = stakeInfo(
            _gameId,
            _player,
            amount - _fee
        );
        Avoters[_gameId].push(msg.sender); // 添加投票者

        return true;
    }

    function settlement(uint256 _gameId) public returns (bool) {
        require(games[_gameId].exist == 1, "game does not exist");
        require(
            block.timestamp > games[_gameId].endTime,
            "not in settlement period"
        );
        require(games[_gameId].isSettled == 0, "game is settled");

        address[] storage players = Aplayers[_gameId];
        address[] storage voters = Avoters[_gameId];
        require(players.length == 2, "no players in this game");

        uint256 player1Bal = playerStakeBalance[_gameId][players[0]];
        uint256 player2Bal = playerStakeBalance[_gameId][players[1]];
        address winner;
        address loser;
        if (player1Bal > player2Bal) {
            winner = players[0];
            loser = players[1];
        } else {
            winner = players[1];
            loser = players[0];
        }

        uint256 totalWinning = playerStakeBalance[_gameId][winner];
        uint256 totalLosing = playerStakeBalance[_gameId][loser];
        for (uint i = 0; i < voters.length; i++) {
            if (voterGameStake[voters[i]][_gameId].player == winner) {
                uint256 bonus = calculateBonusTwoDecimals(
                    voterGameStake[voters[i]][_gameId].stakeAmount,
                    totalWinning,
                    totalLosing
                );
                uint256 _total = bonus +
                    voterGameStake[voters[i]][_gameId].stakeAmount;
                transferToken(voters[i], _total);
                emit Settle(_gameId, voters[i], block.timestamp, _total);
            }
        }
        games[_gameId].isSettled = 1;
        emit Settled(_gameId, winner, block.timestamp);
        return true;
    }

    function transferToken(
        address _to,
        uint256 _amount
    ) internal checkAuthority returns (bool) {
        IERC20(token).transfer(_to, _amount);
        return true;
    }

    function joinGame(uint256 _gameId) public returns (bool) {
        require(games[_gameId].exist == 1, "game is not exist");
        // require(games[_gameId].isSettled == 0, "game is settled");
        require(!(isPlayer[_gameId][msg.sender] == true), "already join game");
        address[] storage players = Aplayers[_gameId];
        require(players.length < 2 && players.length != 2, "Game is full");
        players.push(msg.sender);
        isPlayer[_gameId][msg.sender] = true;
        emit JoinGame(_gameId, msg.sender);
        return true;
    }

    function isVoting(uint256 _gameId) public view returns (bool) {
        return block.timestamp > games[_gameId].endTime;
    }

    function forceGameOver(
        uint256 _gameId
    ) public checkAuthority returns (bool) {
        require(games[_gameId].exist == 1, "game does not exist");
        if (games[_gameId].endTime < block.timestamp) {
            revert GameAlreadyOver();
        }
        games[_gameId].endTime = block.timestamp;
        return true;
    }

    function calculateBonusTwoDecimals(
        uint256 _stake,
        uint256 totalWinning,
        uint256 totalLosing
    ) public pure returns (uint256 bonus) {
        require(totalWinning > 0, "totalWinning must be > 0");
        int128 stakeFP = ABDKMath64x64.fromUInt(_stake);
        int128 totalWinningFP = ABDKMath64x64.fromUInt(totalWinning);
        int128 totalLosingFP = ABDKMath64x64.fromUInt(totalLosing);
        int128 proportion = ABDKMath64x64.div(stakeFP, totalWinningFP);
        int128 bonusFP = ABDKMath64x64.mul(totalLosingFP, proportion);
        uint256 bonusTimes100 = ABDKMath64x64.toUInt(
            ABDKMath64x64.mul(bonusFP, ABDKMath64x64.fromUInt(100))
        );
        bonus = bonusTimes100 / 100;
        return bonus;
    }

    function addWhiteList(address addr) public checkAuthority returns (bool) {
        whiteList[addr] = true;
        return true;
    }

    // 获取当前游戏总数
    function getGameCount() public view returns (uint256) {
        return _nonce;
    }

    function setSt(uint256 _time) public checkAuthority {
        startAppend = _time;
    }

    function setEt(uint256 _time) public checkAuthority {
        endAppend = _time;
    }
}
