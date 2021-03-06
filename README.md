# Tron Ark

中文版本说明见[这里](https://github.com/norchain/Rowing/blob/master/%E8%AF%BB%E6%88%91.md)



The last four Arks are trying to escape from the deluge of doom, but only the single fastest one can survive and inherit the human fortune. When they meet the dying people on the way, the passengers can choose to allow their embarkment with immediate tax, but doing so would reduce the speed with higher load. 

Which Ark will find and practise the best strategy?

**Tron Ark** is a blockchain game based on [Tron network](https://tron.network/index?lng=en). 



## Gameplay

The game rule is simple with only one action: **Embark**. To do so, a player needs to declare which ark to embark and how much crypto he is bringing. At meanwhile, it's optional for he to vote "restrict embarkment". An Embarkment brings three effects:

1. The proportions of the embarked crypto

* **Pool Part**: 10% is deposited to the shared reward pool.
* **Dividend Part**: 40% is deposited to all the existing passengers' accounts on the same ark immediately, following the ratio of each one's total investment.
* **Restricted Part**: 45% is deposited to the passengers' accounts on the same ark, who embarked during the last cycle (see *Cycle* in bullet 3) while didn't vote for "restrict embarking".
* **Referral Part**: For the rest part, 2% is deposited to the referree while 3% to the developer. If the embarkment didn't denote a referree, all 5% are deposited to developer's account.
2. Ark deceleration

   The embarkment bring more load will declerate the ark. The leading ark could be possible gets slow down due to its attraction.

3. Restrict the number of embarkment for the next cycle

* Every 6 hours is called a cycle. At the end of every cycle, each ark will calculate if the "restrict embarkment" votes weighted by the embarked crypto during this cycle exceeds 50%. If so, the number of embarkment in the next cycle is restricted to be maximum 20% of that of the current cycle. Otherwise, there's no limitation of embarkment.
* No matter the restriction vote successful or not, only the passengers who voted "no restrict" are qualified to take the *Restricted Part* from the embarkers in the next cycles.



## Game End Condition and Finalization

When a cycle is ended, if the leading ark keeps the distance from the last ark with more than 24 miles for three continous cycles (including the checking cycle), the game ends.

After the game ended, the crypto in the pool will be dispensed to all the passengers, with the ratio of the total investment they put onto the winner ark during the last 3 cycles.



## Gameplay Analysis

Comparing with the Famous Fomo3D, the restrict voting mechanism can ensure the later participants still be able to achieve high dividend.



## The Team

[Norchain.io](norchain.io) is a technology team based Toronto, Canada. The team members are professionals of blockchain, machine learning, cybersecurity and mobile internet. Norchain has won a lot of global develop competitions and hackathons. 