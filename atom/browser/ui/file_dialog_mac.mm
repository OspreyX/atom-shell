// Copyright (c) 2013 GitHub, Inc. All rights reserved.
// Use of this source code is governed by the MIT license that can be
// found in the LICENSE file.

#include "atom/browser/ui/file_dialog.h"

#import <Cocoa/Cocoa.h>
#import <CoreServices/CoreServices.h>

#include "atom/browser/native_window.h"
#include "base/file_util.h"
#include "base/strings/sys_string_conversions.h"

namespace file_dialog {

namespace {

void SetupDialog(NSSavePanel* dialog,
                 const std::string& title,
                 const base::FilePath& default_path) {
  if (!title.empty())
    [dialog setTitle:base::SysUTF8ToNSString(title)];

  NSString* default_dir = nil;
  NSString* default_filename = nil;
  if (!default_path.empty()) {
    if (base::DirectoryExists(default_path)) {
      default_dir = base::SysUTF8ToNSString(default_path.value());
    } else {
      default_dir = base::SysUTF8ToNSString(default_path.DirName().value());
      default_filename =
          base::SysUTF8ToNSString(default_path.BaseName().value());
    }
  }

  if (default_dir)
    [dialog setDirectoryURL:[NSURL fileURLWithPath:default_dir]];
  if (default_filename)
    [dialog setNameFieldStringValue:default_filename];

  [dialog setCanSelectHiddenExtension:YES];
  [dialog setAllowsOtherFileTypes:YES];
}

void SetupDialogForProperties(NSOpenPanel* dialog, int properties) {
  [dialog setCanChooseFiles:(properties & FILE_DIALOG_OPEN_FILE)];
  if (properties & FILE_DIALOG_OPEN_DIRECTORY)
    [dialog setCanChooseDirectories:YES];
  if (properties & FILE_DIALOG_CREATE_DIRECTORY)
    [dialog setCanCreateDirectories:YES];
  if (properties & FILE_DIALOG_MULTI_SELECTIONS)
    [dialog setAllowsMultipleSelection:YES];
}

// Run modal dialog with parent window and return user's choice.
int RunModalDialog(NSSavePanel* dialog, atom::NativeWindow* parent_window) {
  __block int chosen = NSFileHandlingPanelCancelButton;
  if (!parent_window || !parent_window->GetNativeWindow()) {
    chosen = [dialog runModal];
  } else {
    NSWindow* window = parent_window->GetNativeWindow();

    [dialog beginSheetModalForWindow:window
                   completionHandler:^(NSInteger c) {
      chosen = c;
      [NSApp stopModal];
    }];
    [NSApp runModalForWindow:window];
  }

  return chosen;
}

void ReadDialogPaths(NSOpenPanel* dialog, std::vector<base::FilePath>* paths) {
  NSArray* urls = [dialog URLs];
  for (NSURL* url in urls)
    if ([url isFileURL])
      paths->push_back(base::FilePath(base::SysNSStringToUTF8([url path])));
}

}  // namespace

bool ShowOpenDialog(atom::NativeWindow* parent_window,
                    const std::string& title,
                    const base::FilePath& default_path,
                    int properties,
                    std::vector<base::FilePath>* paths) {
  DCHECK(paths);
  NSOpenPanel* dialog = [NSOpenPanel openPanel];

  SetupDialog(dialog, title, default_path);
  SetupDialogForProperties(dialog, properties);

  int chosen = RunModalDialog(dialog, parent_window);
  if (chosen == NSFileHandlingPanelCancelButton)
    return false;

  ReadDialogPaths(dialog, paths);
  return true;
}

void ShowOpenDialog(atom::NativeWindow* parent_window,
                    const std::string& title,
                    const base::FilePath& default_path,
                    int properties,
                    const OpenDialogCallback& c) {
  NSOpenPanel* dialog = [NSOpenPanel openPanel];

  SetupDialog(dialog, title, default_path);
  SetupDialogForProperties(dialog, properties);

  // Duplicate the callback object here since c is a reference and gcd would
  // only store the pointer, by duplication we can force gcd to store a copy.
  __block OpenDialogCallback callback = c;

  NSWindow* window = parent_window ? parent_window->GetNativeWindow() : NULL;
  [dialog beginSheetModalForWindow:window
                 completionHandler:^(NSInteger chosen) {
    if (chosen == NSFileHandlingPanelCancelButton) {
      callback.Run(false, std::vector<base::FilePath>());
    } else {
      std::vector<base::FilePath> paths;
      ReadDialogPaths(dialog, &paths);
      callback.Run(true, paths);
    }
  }];
}

bool ShowSaveDialog(atom::NativeWindow* parent_window,
                    const std::string& title,
                    const base::FilePath& default_path,
                    base::FilePath* path) {
  DCHECK(path);
  NSSavePanel* dialog = [NSSavePanel savePanel];

  SetupDialog(dialog, title, default_path);

  int chosen = RunModalDialog(dialog, parent_window);
  if (chosen == NSFileHandlingPanelCancelButton || ![[dialog URL] isFileURL])
    return false;

  *path = base::FilePath(base::SysNSStringToUTF8([[dialog URL] path]));
  return true;
}

void ShowSaveDialog(atom::NativeWindow* parent_window,
                    const std::string& title,
                    const base::FilePath& default_path,
                    const SaveDialogCallback& c) {
  NSSavePanel* dialog = [NSSavePanel savePanel];

  SetupDialog(dialog, title, default_path);

  __block SaveDialogCallback callback = c;

  NSWindow* window = parent_window ? parent_window->GetNativeWindow() : NULL;
  [dialog beginSheetModalForWindow:window
                 completionHandler:^(NSInteger chosen) {
    if (chosen == NSFileHandlingPanelCancelButton) {
      callback.Run(false, base::FilePath());
    } else {
      std::string path = base::SysNSStringToUTF8([[dialog URL] path]);
      callback.Run(true, base::FilePath(path));
    }
  }];
}

}  // namespace file_dialog
