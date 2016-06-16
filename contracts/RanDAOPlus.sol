import "./ProofLib.sol";

contract RanDAOPlus {
    using ProofLib for ProofLib.Proof;

    //EVENTS FOR DEBUGGING ONLY



    uint constant timeout = 10;
    uint constant difficultyTarget = 6;
    uint constant proofRoundTime = 5;

    uint difficulty;

    mapping(uint => bytes32) finalizedRandomNumbers; //Maps block numbers to random numbers: One random number is generated per block

    ProofLib proofLib;

    struct Proposal {
        uint block;
        bytes32 proposal;
        uint deposit;
        address depositor;
        mapping(address => ProofLib.Proof) challenges;
        bool disproven;
    }

    struct PendingBlock {
        uint blockNumber;
        uint difficulty;
        uint depositLimit;
        mapping(bytes32 => uint) depositTotals;
        mapping(address => Proposal) proposals;
        mapping(bytes32 => uint) submissionTimes;

        bytes32 topProposal;
        uint timer;
    }

    mapping(uint => PendingBlock) pending;

    function RanDAOPlus(address proof) {
        proofLib = ProofLib(proof);
    }

    function submitProposal(uint blockNum, bytes32 proposal) {
        if (finalizedRandomNumbers[blockNum] != 0 || pending[blockNum].blockNumber == 0) throw;

        Proposal prop = pending[blockNum].proposals[msg.sender];
        prop.block = blockNum;
        prop.proposal = proposal;
        prop.deposit = msg.value;
        prop.depositor = msg.sender;

        pending[blockNum].depositTotals[proposal] += msg.value;

        if (pending[blockNum].depositTotals[proposal] > pending[blockNum].depositTotals[pending[blockNum].topProposal] && pending[blockNum].depositTotals[proposal] > pending[blockNum].depositLimit) {
            pending[blockNum].topProposal = proposal;
            pending[blockNum].timer = blockNum + timeout;
        }

        if (pending[blockNum].submissionTimes[proposal] == 0) {
            pending[blockNum].submissionTimes[proposal] = block.number;
        }
    }

    function newChallenge(uint blockNum, address defender) {
        ProofLib.Proof proof = pending[blockNum].proposals[defender].challenges[msg.sender];

        proof.newChallenge(defender, msg.sender, block.blockhash(blockNum), pending[blockNum].proposals[defender].proposal, pending[blockNum].difficulty, proofRoundTime);
        pending[blockNum].depositTotals[pending[blockNum].proposals[defender].proposal] -= pending[blockNum].proposals[defender].deposit;
    }

    function challenge(uint block, address defender, bool correct) {
        pending[block].proposals[defender].challenges[msg.sender].challenge(correct);
    }

    function respond(uint block, address challenger, bytes32 response) {
        pending[block].proposals[msg.sender].challenges[challenger].respond(response);
    }

    function finalize(uint blockNum, address defender, address challenger) {
        ProofLib.Proof proof = pending[blockNum].proposals[defender].challenges[challenger];
        bool challengeSuccessful = proof.finalize();
        distributeRewards(proof, challengeSuccessful, blockNum);
        delete pending[blockNum].proposals[defender].challenges[challenger];
    }

    function distributeRewards(ProofLib.Proof proof, bool challengeSuccessful, uint blockNum) private { //Make sure loopback attacks not possible
        if (challengeSuccessful) {
            proof.challenger.send(pending[blockNum].proposals[proof.defender].deposit * 2);
            pending[blockNum].proposals[proof.defender].disproven = true;
        } else {
            proof.defender.send(pending[blockNum].proposals[proof.defender].deposit);
        }
    }

    function challengeTimeout(uint blockNum, bool isDefender, address opponent) {
        ProofLib.Proof proof;

        if (isDefender) {
            proof = pending[blockNum].proposals[msg.sender].challenges[opponent];
        } else {
            proof = pending[blockNum].proposals[opponent].challenges[msg.sender];
        }

        if (proof.roundTime + proof.lastRound < block.number) {
            if (proof.currentVal == 0) {
                distributeRewards(proof, true, blockNum);
            } else {
                distributeRewards(proof, false, blockNum);
            }
        }
    }

    function finalizeNumber(uint blockNum) {
        if (pending[blockNum].topProposal != 0 && pending[blockNum].timer <= block.number) {
            finalizedRandomNumbers[blockNum] = pending[blockNum].topProposal;
            adjustDifficulty(blockNum - pending[blockNum].submissionTimes[pending[blockNum].topProposal]);
            delete pending[blockNum];

        }
    }

    function adjustDifficulty(uint blocksToVerify) {
        difficulty = difficultyTarget / blocksToVerify * difficulty; //TODO: Simulate network difficulty adjustment -- optimise algo
    }

    function sha(bytes32 seed) constant returns(bytes32){
        return sha3(seed);
    }

    function getProof(uint blockNum, address defender, address challenger) constant returns (uint,uint,bytes32,bytes32,bytes32){
      return pending[blockNum].proposals[defender].challenges[challenger].getProof();
    }

    function test() returns (uint){
        return ProofLib.test();
    }
}
