import "MetadataViews"
import "TGSLogging"
import "TGSDataCenter"
import "TGSEntity"
import "TGSInterfaces"
import "TGSPlatform"
import "TGSApplication"
import "PropertyService"
import "PropertyProfile"

transaction(
    name: String,
    platform: String,
    platformUid: String,
    tgsUid: String
) {
    let platformRef: &TGSPlatform.Entity{TGSPlatform.PlatformController, TGSLogging.LoggableResource, TGSEntity.EntityPublic, TGSEntity.EntityPrivate}
    let applicationRef: &TGSApplication.Entity{TGSApplication.ApplicationPublic, TGSInterfaces.AccountManagerAccessor, TGSApplication.ApplicationManager, TGSInterfaces.DisplayProperties, MetadataViews.Resolver}
    let serviceType: Type

    prepare(acct: AuthAccount) {
        let ctrlCap = acct
            .borrow<&Capability<&TGSPlatform.Entity{TGSPlatform.PlatformController, TGSLogging.LoggableResource, TGSEntity.EntityPublic, TGSEntity.EntityPrivate}>>
            (from: TGSPlatform.getStandardControllerPath(acct.address))
            ?? panic("Failed to borrow a reference to the TGSPlatform controller")
        self.platformRef = ctrlCap.borrow()
            ?? panic("Failed to borrow a reference to the TGSPlatform controller")

        let appAddress = self.platformRef.getApplicationAddress(name)
            ?? panic("Application does not exist")
        self.applicationRef = self.platformRef.borrowApplicationPrivate(appAddress)
            ?? panic("Failed to borrow a reference to the application")
        self.serviceType = PropertyService.getServiceIdentityType()
    }

    pre {
        !self.applicationRef.isProfileTaked(self.serviceType, platform, platformUid): "Profile is already taked"
    }

    execute {
        let tgsPlatform = TGSDataCenter.getPrimaryPlatfromKey()
        let tgsUserAddress = TGSDataCenter.getAddressByThirdpartyUid(tgsPlatform, tgsUid)
            ?? panic("TGSUser does not exist")

        let appAddress = self.applicationRef.owner?.address
            ?? panic("Application does not have owner")
        self.platformRef.takeUserProfileFromApplication(appAddress, self.serviceType, platform, platformUid, tgsUserAddress)

        log("PropertyProfile is taked for User["
            .concat(tgsUid).concat(" -> ").concat(tgsUserAddress.toString())
            .concat("] linked to [").concat(platform).concat(":").concat(platformUid).concat("]")
        )
    }
}
