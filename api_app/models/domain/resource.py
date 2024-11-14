"""
This module defines data models for managing resources within the application.
These models represent the structure and types of data related to resources,
including their types, history, available upgrades, and main resource attributes.

Key functionalities include:
- Defining enumerations for resource types.
- Creating data models for resource history items and available upgrades.
- Implementing the main Resource model, which includes fields for tracking the
  resource's metadata, properties, status, and available upgrades.
- Providing utility methods for generating resource request message payloads.

Note: This module does not instantiate CosmosDB objects directly. It focuses on defining
the data structures that may be stored in or retrieved from a CosmosDB database.
"""

from enum import Enum
from typing import Optional, Union, List
from pydantic import BaseModel, Field, validator
from models.domain.azuretremodel import AzureTREModel
from models.domain.request_action import RequestAction
from resources import strings


class ResourceType(str, Enum):
    """
    Type of resource to deploy
    """
    Workspace = strings.RESOURCE_TYPE_WORKSPACE
    WorkspaceService = strings.RESOURCE_TYPE_WORKSPACE_SERVICE
    UserResource = strings.USER_RESOURCE
    SharedService = strings.RESOURCE_TYPE_SHARED_SERVICE


class ResourceHistoryItem(AzureTREModel):
    """
    Resource History Item - to preserve history of resource properties
    """
    id: str = Field(title="Id", description="GUID identifying the resource request")
    resourceId: str = Field(title="Id", description="GUID identifying the resource request")
    properties: dict = Field({}, title="Resource template parameters", description="Parameters for the deployment")
    isEnabled: bool = True
    resourceVersion: int = 0
    updatedWhen: float = 0
    user: dict = {}
    templateVersion: Optional[str] = Field(title="Resource template version", description="The version of the resource template (bundle) to deploy")


class AvailableUpgrade(BaseModel):
    version: str
    forceUpdateRequired: bool


class Resource(AzureTREModel):
    """
    Resource request
    """
    id: str = Field(title="Id", description="GUID identifying the resource request")
    templateName: str = Field(title="Resource template name", description="The resource template (bundle) to deploy")
    templateVersion: str = Field(title="Resource template version", description="The version of the resource template (bundle) to deploy")
    properties: dict = Field({}, title="Resource template parameters", description="Parameters for the deployment")
    availableUpgrades: Optional[List[AvailableUpgrade]] = Field(title="Available template upgrades", description="Versions of the template that are available for upgrade")
    isEnabled: bool = True  # Must be set before a resource can be deleted
    resourceType: ResourceType
    deploymentStatus: Optional[str] = Field(title="Deployment Status", description="Overall deployment status of the resource")
    etag: str = Field(title="_etag", description="eTag of the document", alias="_etag")
    resourcePath: str = ""
    resourceVersion: int = 0
    user: dict = {}
    updatedWhen: float = 0

    def get_resource_request_message_payload(self, operation_id: str, step_id: str, action: RequestAction) -> dict:
        payload = {
            "operationId": operation_id,
            "stepId": step_id,
            "action": action,
            "id": self.id,
            "name": self.templateName,
            "version": self.templateVersion,
            "parameters": self.properties
        }

        if self.resourceType == ResourceType.WorkspaceService:
            payload["workspaceId"] = self.workspaceId

        if self.resourceType == ResourceType.UserResource:
            payload["workspaceId"] = self.workspaceId
            payload["ownerId"] = self.ownerId
            payload["parentWorkspaceServiceId"] = self.parentWorkspaceServiceId

        return payload

    # SQL API CosmosDB saves etag as an escaped string by default, with no apparent way to change it.
    # Removing escaped quotes on pydantic deserialization. https://github.com/microsoft/AzureTRE/issues/1931
    @validator("etag", pre=True)
    def parse_etag_to_remove_escaped_quotes(cls, value):
        return value.replace('\"', '')


class Output(AzureTREModel):
    Name: str = Field(title="", description="", alias="name")
    Value: Union[list, dict, str] = Field(None, title="", description="", alias="value")
    Type: str = Field(title="", description="", alias="type")
