#allowAccountLinking

import "FungibleToken"
import "FlowToken"
import "MetadataViews"

import "TGSLogging"
import "TGSEntity"
import "TGSPlatform"
import "TGSApplication"

transaction(
    name: String,
    pubKey: String,
    initialFundingAmt: UFix64,
) {
    prepare(acct: AuthAccount) {
        /* --- Validation --- */
        let platfromPub = TGSPlatform.borrowPlatformPublic()
        assert(
            platfromPub.getApplicationAddress(name) == nil,
            message: "The application name is already in use"
        )

        /* --- Account Creation --- */
        //
        // Create the child account, funding via the signing app account
        let newAccount = AuthAccount(payer: acct)
        // Create a public key for the child account from string value in the provided arg
        // **NOTE:** You may want to specify a different signature algo for your use case
        let key = PublicKey(
            publicKey: pubKey.decodeHex(),
            signatureAlgorithm: SignatureAlgorithm.ECDSA_P256
        )
        // Add the key to the new account
        // **NOTE:** You may want to specify a different hash algo & weight best for your use case
        newAccount.keys.add(
            publicKey: key,
            hashAlgorithm: HashAlgorithm.SHA3_256,
            weight: 1000.0
        )

        /* --- (Optional) Additional Account Funding --- */
        //
        // Fund the new account if specified
        if initialFundingAmt > 0.0 {
            // Get a vault to fund the new account
            let fundingProvider = acct.borrow<&FlowToken.Vault{FungibleToken.Provider}>(
                    from: /storage/flowTokenVault
                )!
            // Fund the new account with the initialFundingAmount specified
            let receiverCap = newAccount.getCapability(/public/flowTokenReceiver)
                .borrow<&FlowToken.Vault{FungibleToken.Receiver}>()
                ?? panic("Could not borrow receiver reference to the new account")
            receiverCap.deposit(
                from: <- fundingProvider.withdraw(amount: initialFundingAmt)
            )
            let vaultRef = newAccount.getCapability(/public/flowTokenBalance)
                .borrow<&FlowToken.Vault{FungibleToken.Balance}>()
                ?? panic("Could not borrow Balance reference to the Vault")
            log("Flow Balance: ".concat(vaultRef.balance.toString()))
        }

        /* --- Borrow TGS Platform Contoller --- */

        let ctrlCap = acct
            .borrow<&Capability<&TGSPlatform.Entity{TGSPlatform.PlatformController, TGSLogging.LoggableResource, TGSEntity.EntityPublic, TGSEntity.EntityPrivate}>>
            (from: TGSPlatform.getStandardControllerPath(acct.address))
            ?? panic("Failed to borrow a reference to the TGSPlatform controller")
        let ctrl = ctrlCap.borrow()
            ?? panic("Failed to borrow a reference to the TGSPlatform controller")

        /* --- Initialize Application --- */

        let cap = newAccount.capabilities.account.issue<&AuthAccount>()
        ctrl.initializeNewApplicationAccount(name: name, cap)

        log("Application account initialized: ".concat(name).concat(" -> ").concat(newAccount.address.toString()))
    }
}
