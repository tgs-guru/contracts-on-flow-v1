import "TGSLogging"
import "TGSEntity"
import "TGSInterfaces"
import "TGSPlatform"
import "TGSApplication"
import "PropertyService"

pub fun main(
    name: String,
    platform: String,
    platformUid: String,
): Bool {
    let tgsAddr = TGSPlatform.borrowPlatformPublic().owner!.address
    let acct = getAuthAccount(tgsAddr)
    let ctrlCap = acct
        .borrow<&Capability<&TGSPlatform.Entity{TGSPlatform.PlatformController, TGSLogging.LoggableResource, TGSEntity.EntityPublic, TGSEntity.EntityPrivate}>>
        (from: TGSPlatform.getStandardControllerPath(acct.address))
        ?? panic("Failed to borrow a reference to the TGSPlatform controller")
    let ctrlRef = ctrlCap.borrow()
        ?? panic("Failed to borrow a reference to the TGSPlatform controller")

    let appAddress = ctrlRef.getApplicationAddress(name)
        ?? panic("Application does not exist")
    let applicationRef = ctrlRef.borrowApplicationPrivate(appAddress)
        ?? panic("Failed to borrow a reference to the application")

    let serviceType = PropertyService.getServiceIdentityType()
    return applicationRef.borrowProfile(serviceType, platform, platformUid) != nil
}
