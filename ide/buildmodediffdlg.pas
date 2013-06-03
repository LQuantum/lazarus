{
 ***************************************************************************
 *                                                                         *
 *   This source is free software; you can redistribute it and/or modify   *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This code is distributed in the hope that it will be useful, but      *
 *   WITHOUT ANY WARRANTY; without even the implied warranty of            *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU     *
 *   General Public License for more details.                              *
 *                                                                         *
 *   A copy of the GNU General Public License is available on the World    *
 *   Wide Web at <http://www.gnu.org/copyleft/gpl.html>. You can also      *
 *   obtain it by writing to the Free Software Foundation,                 *
 *   Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.        *
 *                                                                         *
 ***************************************************************************

 Abstract:
   Modal dialog to show the differences between build modes.
}
unit BuildModeDiffDlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, LazUTF8, LazLogger, Forms, ButtonPanel, StdCtrls, ComCtrls,
  LazarusIDEStrConsts, EnvironmentOpts, Project,
  ModeMatrixOpts, CompOptsModes;

type

  { TBuildModeDiffDialog }

  TBuildModeDiffDialog = class(TForm)
    ButtonPanel: TButtonPanel;
    DiffsGroupBox: TGroupBox;
    DiffTreeView: TTreeView;
    ModeComboBox: TComboBox;
    ModeLabel: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure ModeComboBoxChange(Sender: TObject);
  private
    FBaseMode: TProjectBuildMode;
    fProject: TProject;
    procedure FillModeComboBox;
    procedure FillDiffTreeView;
  public
    procedure SetBuildMode(aMode: TProjectBuildMode);
    property LazProject: TProject read fProject;
    property BaseMode: TProjectBuildMode read FBaseMode;
  end;

function ShowBuildModeDiffDialog(AProject: TProject; aMode: TProjectBuildMode): TModalResult;
procedure AddDiff(MatrixOptions: TBuildMatrixOptions; OldMode, NewMode: string; Diff: TStrings);

implementation


function ShowBuildModeDiffDialog(AProject: TProject; aMode: TProjectBuildMode): TModalResult;
var
  BuildModeDiffDialog: TBuildModeDiffDialog;
begin
  BuildModeDiffDialog:=TBuildModeDiffDialog.Create(nil);
  try
    BuildModeDiffDialog.fProject:=AProject;
    BuildModeDiffDialog.SetBuildMode(aMode);
    Result:=BuildModeDiffDialog.ShowModal;
  finally
    BuildModeDiffDialog.Free;
  end;
end;

procedure AddDiff(MatrixOptions: TBuildMatrixOptions; OldMode, NewMode: string;
  Diff: TStrings);
var
  i: Integer;
  Option: TBuildMatrixOption;
  HasOldMode: Boolean;
  HasNewMode: Boolean;
  s: String;
begin
  if MatrixOptions=nil then exit;
  for i:=0 to MatrixOptions.Count-1 do begin
    Option:=MatrixOptions[i];
    HasOldMode:=Option.FitsMode(OldMode);
    HasNewMode:=Option.FitsMode(NewMode);
    if HasOldMode=HasNewMode then continue;
    if HasOldMode then
      s:=lisDoesNotHaveMatrixOption
    else
      s:=lisHasMatrixOption;
    s+=BuildMatrixOptionTypeNames[Option.Typ]+':';
    if Option.Typ=bmotIDEMacro then
      s+=dbgstr(Option.MacroName)+':=';
    s+=dbgstr(Option.Value);
    Diff.Add(s);
  end;
end;

{$R *.lfm}

{ TBuildModeDiffDialog }

procedure TBuildModeDiffDialog.FormCreate(Sender: TObject);
begin
  Caption:=lisBuildModeDiffDifferencesBetweenBuildModes;

  ModeLabel.Caption:=lisBuildModeDiffMode;
  DiffsGroupBox.Caption:=lisBuildModeDiffDifferencesToOtherBuildModes;
  ButtonPanel.CloseButton.Caption:=lisBtnClose;
end;

procedure TBuildModeDiffDialog.ModeComboBoxChange(Sender: TObject);
var
  i: Integer;
begin
  if fProject<>nil then
    for i:=0 to fProject.BuildModes.Count-1 do
      if UTF8CompareText(fProject.BuildModes[i].GetCaption,ModeComboBox.Text)=0
      then begin
        fBaseMode:=fProject.BuildModes[i];
        FillDiffTreeView;
        break;
      end;
end;

procedure TBuildModeDiffDialog.FillModeComboBox;
var
  sl: TStringList;
  i: Integer;
begin
  sl:=TStringList.Create;
  try
    if fProject<>nil then
      for i:=0 to fProject.BuildModes.Count-1 do
        sl.Add(fProject.BuildModes[i].GetCaption);
    ModeComboBox.Items.Assign(sl);
    if BaseMode<>nil then begin
      ModeComboBox.Text:=BaseMode.GetCaption;
      ModeComboBox.ItemIndex:=sl.IndexOf(BaseMode.GetCaption);
    end
    else
      ModeComboBox.Text:='(none)';
  finally
    sl.Free;
  end;
end;

procedure TBuildModeDiffDialog.FillDiffTreeView;
var
  i: Integer;
  CurMode: TProjectBuildMode;
  ModeNode: TTreeNode;
  Diff: TStringList;
  DiffTool: TCompilerDiffTool;
  j: Integer;
begin
  DiffTreeView.BeginUpdate;
  DiffTreeView.Items.Clear;
  if fProject<>nil then
  begin
    for i := 0 to fProject.BuildModes.Count - 1 do
    begin
      CurMode:=fProject.BuildModes[i];
      if CurMode=BaseMode then continue;
      ModeNode:=DiffTreeView.Items.Add(nil,CurMode.GetCaption);
      Diff:=TStringList.Create;
      DiffTool:=TCompilerDiffTool.Create(Diff);
      BaseMode.CreateDiff(CurMode,DiffTool);
      AddDiff(EnvironmentOptions.BuildMatrixOptions,
              CurMode.Identifier,BaseMode.Identifier,Diff);
      AddDiff(fProject.BuildModes.SharedMatrixOptions,
              CurMode.Identifier,BaseMode.Identifier,Diff);
      AddDiff(fProject.BuildModes.SessionMatrixOptions,
              CurMode.Identifier,BaseMode.Identifier,Diff);
      for j:=0 to Diff.Count-1 do
        DiffTreeView.Items.AddChild(ModeNode,Diff[j]);
      DiffTool.Free;
      Diff.Free;
      ModeNode.Expand(true);
    end;
  end;
  DiffTreeView.EndUpdate;
end;

procedure TBuildModeDiffDialog.SetBuildMode(aMode: TProjectBuildMode);
begin
  if aMode<>nil then
  begin
    if aMode.LazProject<>nil then
      fProject:=aMode.LazProject;
    FBaseMode:=aMode;
  end else
  begin
    FBaseMode:=nil;
  end;
  FillModeComboBox;
  FillDiffTreeView;
end;

end.

