import "TGSLogging"
import "TGSEntity"
import "TGSPlatform"

transaction {
    prepare(acct: AuthAccount) {
        let controllerPath = TGSPlatform.getStandardControllerPath(acct.address)
        if acct.borrow<&Capability>(from: controllerPath) == nil{
            let name = TGSPlatform.getControllerIdentifier(acct.address)
            let platform = TGSPlatform.borrowPlatformPublic()
            // claim the capability
            let cap = acct.inbox
                .claim<&TGSPlatform.Entity{TGSPlatform.PlatformController, TGSLogging.LoggableResource, TGSEntity.EntityPublic, TGSEntity.EntityPrivate}>
                (name, provider: platform.getAddress() )
                ?? panic("Failed to claim the capability from the inbox")
            // store the cap in the controller path
            acct.save(cap, to: controllerPath)
        }
    }
}
