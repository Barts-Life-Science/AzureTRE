import React, { useEffect, useState } from "react";
import {
  PrimaryButton,
  Stack,
  Dropdown,
  IDropdownOption,
  Checkbox,
  Text,
} from "@fluentui/react";
import { HttpMethod, ResultType, useAuthApiCall } from "../../hooks/useAuthApiCall";
import { ApiEndpoint } from "../../models/apiEndpoints";
import { GenericTable } from "./GenericTable";


interface ServiceVersion {
  version: string;
  description: string;
  enabled: {
    TRE: boolean;
    Workspace: boolean;
  };
}

interface Service {
  name: string;
  title: string;
  versions: ServiceVersion[];
}

interface Workspace {
  id: string;
  properties: {
    display_name: string;
    service_template_versions: Service[];
  };
  _etag: string
}

interface WorkspacesResponse {
  workspaces: Workspace[];
}

interface UpdateRequest {
  workspaceId: string;
  workspaceEtag: string;
  payload: {
    properties: {
      service_template_versions: Service[];
    };
  };
}

export const TreAdminConfiguration: React.FC = () => {
  const [services, setServices] = useState<Service[]>([]);
  const [selectedService, setSelectedService] = useState<Service | undefined>(undefined);
  const [workspaces, setWorkspaces] = useState<Workspace[]>([]);
  const [updatedWorkspaces, setUpdatedWorkspaces] = useState<Record<string, Record<string, Record<string, boolean>>>>({});
  const [refreshTrigger, setRefreshTrigger] = useState(false);
  const [updateErrors, setUpdateErrors] = useState<string[]>([]);


  const apiCall = useAuthApiCall();

  useEffect(() => {
    const getWorkspaceVersions = async () => {
      const response = await apiCall(ApiEndpoint.Workspaces, HttpMethod.Get) as WorkspacesResponse;

      if (!response?.workspaces) {
        console.error("No workspaces found in API response");
        return;
      }

      setWorkspaces(response.workspaces);

      const uniqueServices = Array.from(
        new Map(
          response.workspaces.flatMap((ws) =>
            ws.properties.service_template_versions.map((service) => [`${service.name}-${service.title}`, service])
          )
        ).values()
      );

      setServices(uniqueServices);
      if (uniqueServices.length > 0) {
        setSelectedService(uniqueServices[0]);
      }
    };

    getWorkspaceVersions();
  }, [apiCall, refreshTrigger]);

  const handleServiceChange = (event: React.FormEvent<HTMLDivElement>, option?: IDropdownOption) => {
    const selected = services.find(service => service.name === option?.key);
    setSelectedService(selected);
  };

  const handleCheckboxChange = (workspaceId: string, serviceName: string, version: string) => {
    setUpdatedWorkspaces((prev) => ({
      ...prev,
      [workspaceId]: {
        ...prev[workspaceId],
        [serviceName]: {
          ...prev[workspaceId]?.[serviceName],
          [version]: !prev[workspaceId]?.[serviceName]?.[version],
        },
      },
    }));
  };

  const allVersions = workspaces.flatMap(ws =>
    ws.properties.service_template_versions
      .find(service => service.name === selectedService?.name)?.versions.map(ver => ver.version) || []
  );

  const uniqueVersions = Array.from(new Set(allVersions));

  const tableData = workspaces.map((ws) => {
    const service = ws.properties.service_template_versions.find(
      (s) => s.name === selectedService?.name
    );

    return {
      name: ws.properties.display_name,
      ...Object.fromEntries(
        uniqueVersions.map((ver) => {
          const existingVersion = service?.versions.find((v) => v.version === ver);
          const defaultChecked = existingVersion?.enabled?.TRE ?? false;

          return [
            ver,
            <Checkbox
              key={ver}
              checked={updatedWorkspaces[ws.id]?.[selectedService?.name!]?.[ver] ?? defaultChecked}
              onChange={() => handleCheckboxChange(ws.id, selectedService?.name!, ver)}
            />,
          ];
        })
      ),
    };
  });

  const tableColumns = [
    { key: "name", name: "Workspace Name", render: (item: any) => <Text>{item.name}</Text> },
    ...uniqueVersions.map(ver => ({
      key: ver,
      name: `v${ver}`,
      render: (item: any) => item[ver]
    })),
  ];



  const handleSaveChanges = async () => {
    const servicesList = services

    const updatedRequests = Object.entries(updatedWorkspaces).map(([workspaceId, services]) => {
      const workspace = workspaces.find(ws => ws.id === workspaceId);
      if (!workspace) return null;

      const existingServices = workspace.properties.service_template_versions.length > 0
        ? workspace.properties.service_template_versions
        : servicesList

      const updatedServiceTemplateVersions = existingServices.map(service => {
        if (services[service.name]) {
          return {
            ...service,
            versions: service.versions.map(version => ({
              ...version,
              enabled: {
                ...version.enabled,
                TRE: services[service.name][version.version] ?? version.enabled.TRE,
              },
            })),
          };
        }
        return service;
      });

      return {
        workspaceId,
        workspaceEtag: workspace._etag,
        payload: {
          properties: {
            service_template_versions: updatedServiceTemplateVersions,
          },
        },
      };
    }).filter(Boolean) as UpdateRequest[]

    const failedWorkspaces: string[] = [];


    // Perform PATCH requests
    for (const update of updatedRequests) {
      try {
        await apiCall(
          `${ApiEndpoint.Workspaces}/${update.workspaceId}`,
          HttpMethod.Patch,
          update.workspaceId,
          update.payload,
          ResultType.JSON,
          undefined,
          undefined,
          update.workspaceEtag
        );
        console.log(`Updated workspace ${update.workspaceId} successfully.`);
      } catch (error) {
        console.error(`Failed to update workspace ${update.workspaceId}`, error);

        // Find the workspace title from state
        const failedWorkspace = workspaces.find(ws => ws.id === update.workspaceId);
        const workspaceTitle = failedWorkspace?.properties.display_name || `Workspace ${update.workspaceId}`;

        failedWorkspaces.push(workspaceTitle);
      }
    }

    // If any updates failed, store errors
    if (failedWorkspaces.length > 0) {
      setUpdateErrors(failedWorkspaces);
    } else {
      setUpdatedWorkspaces({}); // Clear updated state only if successful
      setRefreshTrigger(prev => !prev);
    }
  };



  return (
    <Stack tokens={{ childrenGap: 15 }} className="tre-panel">
      {/* Main Page Title & Subtext */}
      <Stack>
        <Text variant="xxLarge" styles={{ root: { fontWeight: "bold" } }}>Version Configuration</Text>
        <Text variant="medium" styles={{ root: { color: "#666" } }}>
          Use the dropdown to select a service. Check the versions allowed for each workspace, then click "Save Changes" to apply.
        </Text>
      </Stack>

      {/* Dropdown & Service Title */}
      <Stack>
        <Dropdown
          placeholder="Select a service"
          label="Select a service"
          options={services.map((s) => ({ key: s.name, text: s.title }))}
          onChange={handleServiceChange}
          selectedKey={selectedService?.name}
          styles={{ dropdown: { width: 250 } }}
        />
        {selectedService && (
          <Text variant="xLarge" styles={{ root: { fontWeight: "bold", marginTop: 10 } }}>
            {selectedService.title}
          </Text>
        )}
      </Stack>

      {/* Table */}
      {selectedService && <GenericTable data={tableData} columns={tableColumns} />}

      {/* Save Button */}
      <Stack.Item>
        <PrimaryButton
          iconProps={{ iconName: "Save" }}
          text="Save Changes"
          onClick={handleSaveChanges}
        />
      </Stack.Item>

      {/* Display Updated Workspaces */}
      {Object.keys(updatedWorkspaces).length > 0 && (
        <pre>{JSON.stringify(updatedWorkspaces, null, 2)}</pre>
      )}


      {/* Display Errors if any */}
      {updateErrors.length > 0 && (
        <Text variant="small" styles={{ root: { color: "red", marginTop: 10 } }}>
          Failed to update: {updateErrors.join(", ")}
        </Text>
      )}
    </Stack>

  );
};
