import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import '../cloud/cloud_sync.dart';
import '../cloud/firebase_rest.dart';
import '../storage/data_dir.dart';
import 'cli.dart';

void addDataDirOption(ArgParser parser) => parser.addOption(
  'data-dir',
  help: 'Folder with config.json, cloud.json and usage.',
  defaultsTo: DataDir.defaultPath(),
);

void addEmulatorFlag(ArgParser parser) => parser.addFlag(
  'emulator',
  help: 'Use the Firebase Local Emulator Suite (development).',
  negatable: false,
  hide: true,
);

FirebaseEndpoints endpointsFor(CloudState state, {required bool emulator}) =>
    emulator
    ? FirebaseEndpoints.emulator(projectId: state.projectId)
    : FirebaseEndpoints(apiKey: state.apiKey, projectId: state.projectId);

/// Loads cloud.json of a paired PC or explains what to do.
({DataDir dir, CloudState state}) loadPairedState(ArgResults results) {
  final dir = DataDir(results.option('data-dir')!);
  final json = dir.readJson(dir.cloudFile);
  if (json == null) {
    throw UsageException(
      'This PC is not connected to the cloud. Run `ktc pair` first.',
      '',
    );
  }
  final state = CloudState.fromJson(json);
  if (state.familyId == null) {
    throw UsageException('Pairing was not finished. Run `ktc pair` again.', '');
  }
  return (dir: dir, state: state);
}

CloudSync openSync(CliContext context, CloudState state, ArgResults results) =>
    CloudSync(
      FirebaseRestClient(
        endpointsFor(state, emulator: results.flag('emulator')),
        client: context.httpClient(),
      ),
      state,
    );
