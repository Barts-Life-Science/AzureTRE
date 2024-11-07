import datetime
import json  # Import the json module

def generate_service_data(service_name, versions, user_resources, all_services):
    # Current timestamp in ISO format
    current_time = datetime.datetime.now(datetime.UTC).isoformat()
    
    # Default version template
    default_version = {
        "version": "1.0.0",
        "active": True,
        "createdAt": current_time,
        "deprecationDate": None,
        "endOfLifeDate": None
    }
    
    # Create user resource version template
    def create_user_resource(name):
        return {
            "name": name,
            "versions": [default_version]  # Start with one default version
        }
    
    # Add all services to user_resources
    user_resources.extend(all_services)

    # Create the main service dictionary
    service_data = {
        "name": service_name,
        "versions": versions if versions else [default_version],  # Use provided versions or default
        "userResources": [create_user_resource(res) for res in user_resources]  # Populate user resources
    }

    return service_data


# Example usage
service_name = "Guacamole"
versions = [  # Sample version data for the main service
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
    "name": "Guacamole",
    "versions": [
        {
            "version": "1.0.0",
            "active": false,
            "createdAt": "2022-01-01T00:00:00Z",
            "deprecationDate": "2023-01-01T00:00:00Z",
            "endOfLifeDate": "2024-01-01T00:00:00Z"
        },
        {
            "version": "1.2.0",
            "active": true,
            "createdAt": "2022-06-01T00:00:00Z",
            "deprecationDate": null,
            "endOfLifeDate": null
        }
    ],
    "userResources": [
        {
            "name": "Guacamole Linux VM",
            "versions": [
                {
                    "version": "1.0.0",
                    "active": true,
                    "createdAt": "2024-10-19T16:38:39.346208+00:00",
                    "deprecationDate": null,
                    "endOfLifeDate": null
                }
            ]
        },
        {
            "name": "Guacamole Windows VM",
            "versions": [
                {
                    "version": "1.0.0",
                    "active": true,
                    "createdAt": "2024-10-19T16:38:39.346208+00:00",
                    "deprecationDate": null,
                    "endOfLifeDate": null
                }
            ]
        },
        {
            "name": "admin-vm",
            "versions": [
                {
                    "version": "1.0.0",
                    "active": true,
                    "createdAt": "2024-10-19T16:38:39.346208+00:00",
                    "deprecationDate": null,
                    "endOfLifeDate": null
                }
            ]
        },
        {
            "name": "airlock_notifier",
            "versions": [
                {
                    "version": "1.0.0",
                    "active": true,
                    "createdAt": "2024-10-19T16:38:39.346208+00:00",
                    "deprecationDate": null,
                    "endOfLifeDate": null
                }
            ]
        },
        {
            "name": "azureml",
            "versions": [
                {
                    "version": "1.0.0",
                    "active": true,
                    "createdAt": "2024-10-19T16:38:39.346208+00:00",
                    "deprecationDate": null,
                    "endOfLifeDate": null
                }
            ]
        },
        {
            "name": "azuresql",
            "versions": [
                {
                    "version": "1.0.0",
                    "active": true,
                    "createdAt": "2024-10-19T16:38:39.346208+00:00",
                    "deprecationDate": null,
                    "endOfLifeDate": null
                }
            ]
        },
        {
            "name": "certs",
            "versions": [
                {
                    "version": "1.0.0",
                    "active": true,
                    "createdAt": "2024-10-19T16:38:39.346208+00:00",
                    "deprecationDate": null,
                    "endOfLifeDate": null
                }
            ]
        },
        {
            "name": "cyclecloud",
            "versions": [
                {
                    "version": "1.0.0",
                    "active": true,
                    "createdAt": "2024-10-19T16:38:39.346208+00:00",
                    "deprecationDate": null,
                    "endOfLifeDate": null
                }
            ]
        },
        {
            "name": "databricks-auth",
            "versions": [
                {
                    "version": "1.0.0",
                    "active": true,
                    "createdAt": "2024-10-19T16:38:39.346208+00:00",
                    "deprecationDate": null,
                    "endOfLifeDate": null
                }
            ]
        },
        {
            "name": "databricks",
            "versions": [
                {
                    "version": "1.0.0",
                    "active": true,
                    "createdAt": "2024-10-19T16:38:39.346208+00:00",
                    "deprecationDate": null,
                    "endOfLifeDate": null
                }
            ]
        },
        {
            "name": "firewall",
            "versions": [
                {
                    "version": "1.0.0",
                    "active": true,
                    "createdAt": "2024-10-19T16:38:39.346208+00:00",
                    "deprecationDate": null,
                    "endOfLifeDate": null
                }
            ]
        },
        {
            "name": "sonatype-nexus-vm",
            "versions": [
                {
                    "version": "1.0.0",
                    "active": true,
                    "createdAt": "2024-10-19T16:38:39.346208+00:00",
                    "deprecationDate": null,
                    "endOfLifeDate": null
                }
            ]
        },
        {
            "name": "gitea",
            "versions": [
                {
                    "version": "1.0.0",
                    "active": true,
                    "createdAt": "2024-10-19T16:38:39.346208+00:00",
                    "deprecationDate": null,
                    "endOfLifeDate": null
                }
            ]
        },
        {
            "name": "guacamole",
            "versions": [
                {
                    "version": "1.0.0",
                    "active": true,
                    "createdAt": "2024-10-19T16:38:39.346208+00:00",
                    "deprecationDate": null,
                    "endOfLifeDate": null
                }
            ]
        },
        {
            "name": "health-services",
            "versions": [
                {
                    "version": "1.0.0",
                    "active": true,
                    "createdAt": "2024-10-19T16:38:39.346208+00:00",
                    "deprecationDate": null,
                    "endOfLifeDate": null
                }
            ]
        },
        {
            "name": "innereye",
            "versions": [
                {
                    "version": "1.0.0",
                    "active": true,
                    "createdAt": "2024-10-19T16:38:39.346208+00:00",
                    "deprecationDate": null,
                    "endOfLifeDate": null
                }
            ]
        },
        {
            "name": "mlflow",
            "versions": [
                {
                    "version": "1.0.0",
                    "active": true,
                    "createdAt": "2024-10-19T16:38:39.346208+00:00",
                    "deprecationDate": null,
                    "endOfLifeDate": null
                }
            ]
        },
        {
            "name": "mysql",
            "versions": [
                {
                    "version": "1.0.0",
                    "active": true,
                    "createdAt": "2024-10-19T16:38:39.346208+00:00",
                    "deprecationDate": null,
                    "endOfLifeDate": null
                }
            ]
        },
        {
            "name": "ohdsi",
            "versions": [
                {
                    "version": "1.0.0",
                    "active": true,
                    "createdAt": "2024-10-19T16:38:39.346208+00:00",
                    "deprecationDate": null,
                    "endOfLifeDate": null
                }
            ]
        },
        {
            "name": "openai",
            "versions": [
                {
                    "version": "1.0.0",
                    "active": true,
                    "createdAt": "2024-10-19T16:38:39.346208+00:00",
                    "deprecationDate": null,
                    "endOfLifeDate": null
                }
            ]
        }
    ]
}


"""