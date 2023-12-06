#allowAccountLinking

import "TGSLogging"
import "TGSEntity"
import "TGSPlatform"

transaction {
    prepare(admin: AuthAccount) {
        // check if the platform is already created
        if admin.borrow<&AnyResource>(from: TGSPlatform.TGSPlatformStoragePath) == nil {
            // create a account capability
            let cap = admin.capabilities.account.issue<&AuthAccount>()
            TGSPlatform.createTGSPlatform(cap)
        }

        let platform = admin.borrow<&TGSPlatform.Entity>(from: TGSPlatform.TGSPlatformStoragePath)
            ?? panic("Failed to borrow a reference to the TGSPlatform")

        let addr = admin.address
        let controllerPath = TGSPlatform.getStandardControllerPath(addr)
        if admin.borrow<&Capability>(from: controllerPath) == nil{
            // publish first
            platform.publishControllerCapability(to: addr)

            let name = TGSPlatform.getControllerIdentifier(addr)
            // claim the capability
            let cap = admin.inbox
                .claim<&TGSPlatform.Entity{TGSPlatform.PlatformController, TGSLogging.LoggableResource, TGSEntity.EntityPublic, TGSEntity.EntityPrivate}>
                (name, provider: addr)
                ?? panic("Failed to claim the capability from the inbox")
            // store the cap in the controller path
            admin.save(cap, to: controllerPath)
        }

        log("TGSPlatform initialized.")
    }
}
