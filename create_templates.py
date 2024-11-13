import datetime
import json

def generate_service_data(service_name, versions, user_resources, all_services):
    # Current timestamp in ISO format
    current_time = datetime.datetime.now(datetime.UTC).isoformat()
    
    # Convert version data to new format with TRE Admin and Workspace Admin flags
    def format_version(version_info):
        return {
            version_info["version"]: [
                version_info["active"],  # TRE Admin flag
                version_info["active"]   # Workspace Admin flag - initially matches TRE Admin
            ]
        }
    
    # Create user resource version template
    def create_user_resource(name):
        return {
            "versions": {
                "1.0.0": [True, True]  # Default version with both flags enabled
            }
        }
    
    # Create the main service dictionary with new structure
    service_data = {
        "services": {
            service_name: {
                "versions": [format_version(v) for v in (versions if versions else [{
                    "version": "1.0.0",
                    "active": True
                }])]
            }
        },
        "user-resources": {}
    }
    
    # Add specific user resources for the main service
    for res in user_resources:
        service_data["user-resources"][res] = create_user_resource(res)
    
    # Add all shared services under user-resources
    for service in all_services:
        if service.lower() != service_name.lower():
            service_data["user-resources"][service] = {
                "versions": {
                    "1.0.0": [True, True]
                }
            }
    
    return service_data

# Example usage
service_name = "Guacamole"
versions = [
    {
        "version": "1.0.0",
        "active": False,
        "createdAt": "2022-01-01T00:00:00Z",
        "deprecationDate": "2023-01-01T00:00:00Z",
        "endOfLifeDate": "2024-01-01T00:00:00Z"
    },
    {
        "version": "1.2.0",
        "active": True,
        "createdAt": "2022-06-01T00:00:00Z",
        "deprecationDate": None,
        "endOfLifeDate": None
    }
]
user_resources = ["Guacamole Linux VM", "Guacamole Windows VM"]  # Input list of user resources

# list of all services in alphabetical order
all_services = [
    "admin-vm", "airlock_notifier", "azureml", "azuresql", "certs",
    "cyclecloud", "databricks-auth", "databricks", "firewall", "sonatype-nexus-vm",
    "gitea", "guacamole", "health-services", "innereye", "mlflow",
    "mysql", "ohdsi", "openai"
]

# Generate the service data
service_data = generate_service_data(service_name, versions, user_resources, all_services)

# Print the resulting dictionary in JSON format
print(json.dumps(service_data, indent=4))



"""
Example output


{
    "services": {
        "Guacamole": {
            "versions": [
                {
                    "1.0.0": [
                        false,
                        false
                    ]
                },
                {
                    "1.2.0": [
                        true,
                        true
                    ]
                }
            ]
        }
    },
    "user-resources": {
        "Guacamole Linux VM": {
            "versions": {
                "1.0.0": [
                    true,
                    true
                ]
            }
        },
        "Guacamole Windows VM": {
            "versions": {
                "1.0.0": [
                    true,
                    true
                ]
            }
        },
        "admin-vm": {
            "versions": {
                "1.0.0": [
                    true,
                    true
                ]
            }
        },
        "airlock_notifier": {
            "versions": {
                "1.0.0": [
                    true,
                    true
                ]
            }
        },
        "azureml": {
            "versions": {
                "1.0.0": [
                    true,
                    true
                ]
            }
        },
        "azuresql": {
            "versions": {
                "1.0.0": [
                    true,
                    true
                ]
            }
        },
        "certs": {
            "versions": {
                "1.0.0": [
                    true,
                    true
                ]
            }
        },
        "cyclecloud": {
            "versions": {
                "1.0.0": [
                    true,
                    true
                ]
            }
        },
        "databricks-auth": {
            "versions": {
                "1.0.0": [
                    true,
                    true
                ]
            }
        },
        "databricks": {
            "versions": {
                "1.0.0": [
                    true,
                    true
                ]
            }
        },
        "firewall": {
            "versions": {
                "1.0.0": [
                    true,
                    true
                ]
            }
        },
        "sonatype-nexus-vm": {
            "versions": {
                "1.0.0": [
                    true,
                    true
                ]
            }
        },
        "gitea": {
            "versions": {
                "1.0.0": [
                    true,
                    true
                ]
            }
        },
        "health-services": {
            "versions": {
                "1.0.0": [
                    true,
                    true
                ]
            }
        },
        "innereye": {
            "versions": {
                "1.0.0": [
                    true,
                    true
                ]
            }
        },
        "mlflow": {
            "versions": {
                "1.0.0": [
                    true,
                    true
                ]
            }
        },
        "mysql": {
            "versions": {
                "1.0.0": [
                    true,
                    true
                ]
            }
        },
        "ohdsi": {
            "versions": {
                "1.0.0": [
                    true,
                    true
                ]
            }
        },
        "openai": {
            "versions": {
                "1.0.0": [
                    true,
                    true
                ]
            }
        }
    }
}


"""