library ProofLib {

    struct Proof {
        address defender; //Not guaranteed to be initiallized
        address challenger; // Should hopefully be initialized. Onus is on the challenger to disprove

        uint lVal; //The left hash value of the current frame
        uint rVal; //Right value
        uint lIndex; //The index in the chain that the sliding window starts on-- should only ever move right
        uint rIndex; //The last index that we are examining -- only should move left

        uint roundTime; //Time before "call timeout" should be allowed (in blocks)
        uint lastRound; //Last time a person acted (i.e. start time for current timeout timer)

        uint currentVal; //The value under consideration. 0 indicates defender's turn, any other value indicates challenger's turn

        //TODO: Implement non-participation resilliancy
    }


    function newChallenge(Proof storage self, address _challenger, uint seed, uint result, uint difficulty, uint time) {
        //Normally, defender would be assigned here. TODO: make sure we handle 0 defender properly
        self.challenger = _challenger; // assign challenger

        self.lVal = seed;
        self.rVal = result;

        self.lIndex = 0;
        self.rIndex = difficulty;

        self.roundTime = time; // How long this round can last -- TODO(ish): make sure 0 is handled properly
        self.lastRound = block.number; // Start timer. Challenger initiates, so defender has to respond within roundTime


    }

    function challenge(Proof storage self, bool correct) {
        if (self.currentVal == 0 ||  //Defender hasn't responded yet
            msg.sender != self.challenger) throw;  //Someone's impersonating the challenger TODO: don't do this check twice
        if (correct) {
            self.lIndex = (self.lIndex + self.rIndex) / 2; // If correct, slide window down-chain TODO: understand rounding behavior
            self.lVal = self.currentVal;
        } else {
            self.rIndex = (self.lIndex + self.rIndex) / 2;  // If incorrect, move window upstream
            self.rVal = self.currentVal;
        }

        self.currentVal = 0; // Hand control back to defender
        //TODO: reset timer
    }

    function respond(Proof storage self, uint hash) {
        if (self.currentVal != 0 ||  //It's the challenger's turn
            msg.sender != self.defender) throw; // No impersonating the defender
        self.currentVal = hash; // Assert that currentVal == hash

        //TODO: reset timer
    }

    function finalize(Proof storage self) returns(bool confirmed) { //returns true if challenge successfully disproves proposal

        if (self.rIndex - self.lIndex <= 3) { // Only finalize if we have to do less than 4 hashes (pretty reasonable)
            bytes32 hash = bytes32(self.lVal); // TODO: Worry about types.... Does casting change the sha3 value?

            for (uint i; i < self.rIndex - self.lIndex; i++) { //Finish off the computation
                hash = sha3(hash); //Worry about types....
            }

            if (hash == bytes32(self.rVal)) {  // If the hash checks out, the challenge failed
                return false;
            } else {                           // Else the challenger wins
                return true;
            }
        } else throw;   //Don't go through with the computation if it's longer than 3 hashes
    }


     function getProof(Proof storage self) constant returns(uint,uint,uint,uint,uint){
         return (self.lIndex, self.rIndex, self.lVal, self.currentVal, self.rVal);  //Generic getter for proofs
     }



}