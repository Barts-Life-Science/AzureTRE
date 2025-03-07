import { DefaultButton, Dropdown, MessageBar, MessageBarType, Spinner, SpinnerSize, Stack } from "@fluentui/react";
import { useEffect, useState } from "react";
import { LoadingState } from "../../../models/loadingState";
import { HttpMethod, useAuthApiCall } from "../../../hooks/useAuthApiCall";
import { APIError } from "../../../models/exceptions";
import { ExceptionLayout } from "../ExceptionLayout";

interface SelectTemplateProps {
    templatesPath: string,
    workspaceApplicationIdURI?: string | undefined,
    onSelectTemplate: (templateName: string) => void,
    setTemplateVersion?: (templateVersion: string) => void
}

export const SelectTemplate: React.FunctionComponent<SelectTemplateProps> = (props: SelectTemplateProps) => {
    const [templates, setTemplates] = useState<any[] | null>(null);
    const [loading, setLoading] = useState(LoadingState.Loading as LoadingState);
    const apiCall = useAuthApiCall();
    const [apiError, setApiError] = useState({} as APIError);
    const [selectedVersion, setSelectedVersion] = useState<string | undefined>(undefined);

    useEffect(() => {
        const getTemplates = async () => {
            try {
                const templatesResponse = await apiCall(props.templatesPath, HttpMethod.Get, props.workspaceApplicationIdURI);
                setTemplates(templatesResponse.templates);
                setLoading(LoadingState.Ok);
            } catch (err: any) {
                err.userMessage = 'Error retrieving templates';
                setApiError(err);
                setLoading(LoadingState.Error);
            }
        };

        if (!templates) {
            getTemplates();
        }
    }, [apiCall, props.templatesPath, templates, props.workspaceApplicationIdURI]);

    // Function to generate a mock versions array (1-3 versions)
    const generateMockVersions = () => {
        const numVersions = Math.floor(Math.random() * 3) + 1;
        return Array.from({ length: numVersions }, (_, i) => `0.12.${i + 5}`);
    };

    switch (loading) {
        case LoadingState.Ok:
            return (
                templates && templates.length > 0 ? (
                    <Stack>
                        {templates.map((template: any, i) => {
                            const versions = template?.versions?.length > 0
                                ? template.versions
                                : generateMockVersions();

                            const versionOptions = versions.map((ver: string) => ({
                                key: ver,
                                text: `v${ver}`
                            }));

                            const defaultVersion = versions[versions.length - 1]; // Select last version as default
                            const isSingleVersion = versions.length === 1;
                            const showVersioning = props.templatesPath === "workspace-service-templates" && props.setTemplateVersion;

                            return (
                                <div key={i}>
                                    <h2>{template.title}</h2>
                                    <p>{template.description}</p>
                                    <Stack horizontal tokens={{ childrenGap: 10 }} verticalAlign="end">
                                        {showVersioning && (
                                            <Dropdown
                                                placeholder="Select a version"
                                                label="Select a version"
                                                options={versionOptions}
                                                selectedKey={selectedVersion ?? defaultVersion}
                                                disabled={isSingleVersion}
                                                onChange={(_, option) => setSelectedVersion(option?.key as string)}
                                                styles={{ dropdown: { width: 250 } }}
                                            />
                                        )}
                                        <DefaultButton
                                            text="Create"
                                            onClick={() => {
                                                props.onSelectTemplate(template.name);
                                                if (showVersioning) {
                                                    props.setTemplateVersion?.(selectedVersion ?? defaultVersion);
                                                }
                                            }}
                                        />
                                    </Stack>
                                </div>
                            );
                        })}
                    </Stack>
                ) : (
                    <MessageBar messageBarType={MessageBarType.info} isMultiline={true}>
                        <h3>No templates found</h3>
                        <p>Looks like there aren't any templates registered for this resource type.</p>
                    </MessageBar>
                )
            );
        case LoadingState.Error:
            return <ExceptionLayout e={apiError} />;
        default:
            return (
                <div style={{ marginTop: 20 }}>
                    <Spinner label="Loading templates" ariaLive="assertive" labelPosition="top" size={SpinnerSize.large} />
                </div>
            );
    }
};
