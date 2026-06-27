# Summary

Swift Server SPM library for sending push messages to Apple APNs. It works on MacOS and Linux.

# Project Structure
All new classes/structs/enums put in appropriate folder in separate file. Do not create long files with multiple definitions inside. Although you can add type's extensions in the same file as extended type. If you need extend some object to protocol, name file ObjectType+ProtocolName.swift.

# Available tools
You have docker with images:
- Swift for Linux: `swift:6.1`


# Unit Testing
- Run `swift test` for local unit tests
- Run `docker run --rm -t  -v "$PWD":/workspace -w /workspace swift:6.1 swift test --jobs 1` for unit test on linux

# Change commit
Never commit anything, let user review changes.