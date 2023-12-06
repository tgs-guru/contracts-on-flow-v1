import "MetadataViews"
import "TGSLogging"
import "TGSEntity"
import "TGSPlatform"

pub fun main(name: String): Bool {
    let tgsAddr = TGSPlatform.borrowPlatformPublic().owner!.address
    let acct = getAuthAccount(tgsAddr)

    if let ctrlCap = acct
        .borrow<&Capability<&TGSPlatform.Entity{TGSPlatform.PlatformController, TGSLogging.LoggableResource, TGSEntity.EntityPublic, TGSEntity.EntityPrivate}>>
        (from: TGSPlatform.getStandardControllerPath(acct.address))
    {
        return ctrlCap.borrow()?.getApplicationAddress(name) != nil
    }
    return false
}
