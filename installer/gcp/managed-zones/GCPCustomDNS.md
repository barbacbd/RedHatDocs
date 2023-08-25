# GCP Custom DNS Zones

The doc is created to document the process for allowing users to supply managed dns solutions during an IPI installation.

# Previous Work

- https://github.com/openshift/installer/pull/6288
- https://github.com/openshift/installer/pull/6300
- https://github.com/openshift/cluster-ingress-operator/pull/855

# Configure the Install Config

The install config should accept values for a Private and Public DNS Managed Zone. The same structure will be used for both types of managed zones. The user has the option to supply an `ID` and `ProjectID`.

- ID: A name of the zone. 
- ProjectID: ID or name of the project where the precreated zone resigns.

**Note**: _If a zone has not been granted permission to be shared across projects (if in different projects), then the install will fail._

```
// DNSZone stores the information to use a managed DNS Zone for GCP installations.
type DNSZone struct {
	// ID Technology Preview
	// ID or name of the DNS Zone.
	ID string `json:"id,omitempty"`

	// ProjectID Technology Preview
	// ProjectID is the ID or name of the project where the zone exists.
	ProjectID string `json:"projectID,omitempty"`
}
```

The the structures can be added to the GCP platform struct:

```
// PrivateDNSZone Technology Preview.
// PrivateDNSZone contains the zone ID and project for a public managed DNS Zone.
// +optional
PrivateDNSZone *DNSZone `json:"privateDNSZone,omitempty"`

// PublicDNSZone Technology Preview.
// PublicDNSZone contains the zone ID and project for a public managed DNS Zone.
// +optional
PublicDNSZone *DNSZone `json:"publicDNSZone,omitempty"`
```

# Validation

## Validate Zones can be used for installation

Validation for the zones requires that the zones can be viewed and used during installation. This requires the correct permissions.

```
// validateManagedZones validates the public and private managed zones if they exist. A matching zone must be found
// in order for it to be considered valid.
func validateManagedZones(client API, ic *types.InstallConfig, fieldPath *field.Path) field.ErrorList {
	commonZoneLookup := func(dnsZone, zoneProject, defaultProject string) error {
		project := zoneProject
		if project == "" {
			project = defaultProject
		}

		if _, err := client.GetDNSZoneByName(context.TODO(), project, dnsZone); err != nil {
			return err
		}
		return nil
	}

	allErrs := field.ErrorList{}

	if ic.GCP.PublicDNSZone != nil && ic.GCP.PublicDNSZone.ID != "" {
		if err := commonZoneLookup(ic.GCP.PublicDNSZone.ID, ic.GCP.PublicDNSZone.ProjectID, ic.GCP.ProjectID); err != nil {
			allErrs = append(allErrs, field.Invalid(fieldPath.Child("PublicDNSZone").Child("ID"), ic.GCP.PublicDNSZone.ID, "invalid public managed zone"))
		}
	}

	if ic.GCP.PrivateDNSZone != nil && ic.GCP.PrivateDNSZone.ID != "" {
		if err := commonZoneLookup(ic.GCP.PrivateDNSZone.ID, ic.GCP.PrivateDNSZone.ProjectID, ic.GCP.ProjectID); err != nil {
			allErrs = append(allErrs, field.Invalid(fieldPath.Child("PrivateDNSZone").Child("ID"), ic.GCP.PrivateDNSZone.ID, "invalid private managed zone"))
		}
	}

	return allErrs
}
```

## Validate against install type

During an internal install, the public DNS Zone should not be present.

```
func validateInstallTypeWithZones(ic *types.InstallConfig, fldPath *field.Path) field.ErrorList {
	allErrs := field.ErrorList{}
	
	if ic.Publish == types.InternalPublishingStrategy {
		if ic.Platform.GCP.PublicDNSZone != nil {
			return append(allErrs, field.Invalid(fldPath.Child("PublicDNSZone"), ic.GCP.PublicDNSZone, "private install doest allow public dns zone configuration"))
		}
	}
	
	return allErrs
}
```

## Ensure No Record Sets

Edit the functions `ValidatePrivateDNSZone` and `ValidatePreExistingPublicDNS`. If the private and/or public zones are set, use that information to ensure that no records are created.

```
// findProject finds the correct project to use during installation. If the project id is
// provided in the zone use the project id, otherwise use the default project.
func findProject(zone *gcp.DNSZone, defaultProject string) string {
	if zone != nil && zone.ProjectID != "" {
		return zone.ProjectID
	}
	return defaultProject
}
```

Use the utility function to find the project where the zone should exist.

```
project := findProject(ic.GCP.PrivateDNSZone, ic.GCP.ProjectID)
```

```
project := findProject(ic.GCP.PublicDNSZone, ic.GCP.ProjectID)
```

# Permissions/Roles

Permissions and roles associated with managed zones can be found [here](https://cloud.google.com/dns/docs/access-control). 

## Roles

- `roles/dns.admin`
- `roles/dns.peer` - only required if using zone peering across projects

### Base permissions

- `dns.changes.create`
- `dns.resourceRecordSets.create`

- `dns.resourceRecordSets.list`
- `dns.managedZones.get`
- `dns.managedZones.list`

### Deletion

- `dns.changes.create` (combined with the below permission)
- `dns.resourceRecordSets.delete`


# External vs Internal install

The external installation considerations were mentioned above.	

# Terraform

The public zone must exist prior to the installation. The installer does not use terraform to provision the public zone. Currently, the installer provisions the GCP private managed zone with terraform.

The terraform provider should no longer create a private managed zone in the event that one is supplied via the install config. The private zone, and public zone names should be provided to terraform to indicate:
1. Where records should be created
2. Whether or not the resource (in the case of the private zone) should be created.

```
variable "public_zone_name" {
  description = "The name of the public managed DNS zone"
  type        = string
}

variable "private_zone_name" {
  description = "The name of the private managed DNS zone"
  type        = string
}

variable "public_zone_project" {
  type        = string
  description = "Project where the public managed zone will exist."
}

variable "private_zone_project" {
  type        = string
  description = "Project where the private managed zone will exist."
}
```

Edit the `gcp/cluster/dns/base.tf` file to accept the variables above and ensure that record sets are created in the correct zones.

# Manifests

Edit the `dns.go` file and provide the public or private zone information to the file. Verify that the file `cluster-dns-02-config.yml` has the id for the private and public zones as appropriate.

The format for the long name of the managed zone is `project/%s/managedZones/%s` where the project name and the managed zone name are provided.

**Note**: _The cluster ingress operator was updated to accept this format [PR 855](https://github.com/openshift/cluster-ingress-operator/pull/855)._


# Assumptions

1. The install-config is used to provide the name of a public or private managed zone that already exists.
2. The records will always be created. There cannot be a pre-existing record set in the managed zone(s).