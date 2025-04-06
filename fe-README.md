matchToken: 0xAb5CdC0BA27716eae9E61E0B5a1fABaa2B01E7d6
matchP: 0x5525cc1EB3A7F0c2D6d5869E50f471dF0Ce46160 合约名为 MatchP
已将 0xa93be7581cb37e7fe737350ec3e88f4e06ce6ea4 加入白名单
除了 matchToken 特指方法,其余为 matchP 方法

1.调用 matchP 的 getToken 方法,获取积分和测试币,查看积分 matchP.voteScores,

2.创建赛事: matchP.createGame, startTime 需要>当前时间戳秒数+360(这是最低要求可以拉长增加质押时间), 结束时间许大于 startTime 540 秒

3.参加赛事,一个赛事只有两个参赛者 matchP.jointgame

4.质押前任意用户可以调用getToken方法获取30match 币和30积分, 质押也就是竞猜,对某一个用户地址发起 stake 方法调用,

```Solidity
 具体质押信息:
  mapping(address => mapping(uint256 => stakeInfo)) public voterGameStake;

    struct stakeInfo {
        uint256 gameId;
        address player;
        uint256 stakeAmount;
    }

  对于某个赛事有哪两个参赛者
   mapping(uint256 => address[]) public Aplayers;
   调用Aplayers方法,传入赛事id和参赛者地址

   质押前需要先调用matchToken的approve方法授权matchP合约要质押的数量,以1单位,精确度为1,
   会收手续费,10个match只质押9个,10%手续费


```

5.在比赛结束时间后,可以手动触发结算. settlement()

也可以强行结束比赛,但是只有白名单用户有权限.

note: 后端可能有时间处理,但是能接还是接,演示不好把控时间,需要强行结算.



6.赛事评分待定.
