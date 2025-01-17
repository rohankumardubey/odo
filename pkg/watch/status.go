package watch

import "github.com/devfile/api/v2/pkg/apis/workspaces/v1alpha2"

type State string

const (
	StateWaitDeployment State = "WaitDeployment"
	StateSyncOutdated   State = "SyncOutdated"
	//StateWaitBindings         State = "WaitBindings"
	//StatePodRunning           State = "PodRunning"
	//StateFilesSynced          State = "FilesSynced"
	//StateBuildCommandExecuted State = "BuildCommandExecuted"
	//StateRunCommandRunning    State = "RunCommandRunning"
	StateReady State = "Ready"
)

type ComponentStatus struct {
	State               State
	PostStartEventsDone bool
	// RunExecuted is set to true when the run command has been executed
	// Used for HotReload capability
	RunExecuted        bool
	EndpointsForwarded map[string][]v1alpha2.Endpoint
}

func componentCanSyncFile(state State) bool {
	return state == StateReady
}
