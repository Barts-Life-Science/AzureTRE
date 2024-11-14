"""
This module is responsible for setting up and managing Azure CosmosDB containers
required by the application. It ensures that necessary containers are created if
they do not already exist.

Key functionalities include:
- Establishing a connection to Azure CosmosDB using the CosmosDBManagementClient.
- Creating or updating SQL containers in the CosmosDB account with specified partition keys.
- Handling exceptions and logging errors during the database bootstrap process.

Note: CosmosDB objects such as CosmosDBManagementClient are instantiated in this module
to manage CosmosDB resources.
"""

import asyncio
from azure.mgmt.cosmosdb import CosmosDBManagementClient

from core.config import SUBSCRIPTION_ID, RESOURCE_GROUP_NAME, RESOURCE_LOCATION, COSMOSDB_ACCOUNT_NAME, STATE_STORE_DATABASE, STATE_STORE_RESOURCES_CONTAINER, STATE_STORE_RESOURCE_TEMPLATES_CONTAINER, STATE_STORE_RESOURCES_HISTORY_CONTAINER, STATE_STORE_OPERATIONS_CONTAINER, STATE_STORE_AIRLOCK_REQUESTS_CONTAINER
from core.credentials import get_credential
from services.logging import logger


async def bootstrap_database() -> bool:
    try:
        credential = get_credential()
        db_mgmt_client = CosmosDBManagementClient(credential=credential, subscription_id=SUBSCRIPTION_ID)

        await asyncio.gather(
            create_container_if_not_exists(db_mgmt_client, STATE_STORE_RESOURCES_CONTAINER, "/id"),
            create_container_if_not_exists(db_mgmt_client, STATE_STORE_RESOURCE_TEMPLATES_CONTAINER, "/id"),
            create_container_if_not_exists(db_mgmt_client, STATE_STORE_RESOURCES_HISTORY_CONTAINER, "/resourceId"),
            create_container_if_not_exists(db_mgmt_client, STATE_STORE_OPERATIONS_CONTAINER, "/id"),
            create_container_if_not_exists(db_mgmt_client, STATE_STORE_AIRLOCK_REQUESTS_CONTAINER, "/id")
        )

        return True

    except Exception as e:
        logger.exception("Could not bootstrap database")
        logger.debug(e)
        return False


async def create_container_if_not_exists(db_mgmt_client, container, partition_key):
    db_mgmt_client.sql_resources.begin_create_update_sql_container(
        resource_group_name=RESOURCE_GROUP_NAME,
        account_name=COSMOSDB_ACCOUNT_NAME,
        database_name=STATE_STORE_DATABASE,
        container_name=container,
        create_update_sql_container_parameters={
            "location": RESOURCE_LOCATION,
            "resource": {
                "id": container,
                "partition_key": {
                    "paths": [
                        partition_key
                    ],
                    "kind": "Hash"
                }
            }
        }
    )
