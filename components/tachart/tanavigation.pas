{
 *****************************************************************************
 *                                                                           *
 *  See the file COPYING.modifiedLGPL.txt, included in this distribution,    *
 *  for details about the copyright.                                         *
 *                                                                           *
 *  This program is distributed in the hope that it will be useful,          *
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of           *
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                     *
 *                                                                           *
 *****************************************************************************

Authors: Alexander Klenin

}

unit TANavigation;

{$H+}

interface

uses
  Classes, Controls, Graphics, StdCtrls, TAChartUtils, TAGraph;

type

  { TChartNavScrollBar }

  TChartNavScrollBar = class (TCustomScrollBar)
  private
    FAutoPageSize: Boolean;
    FChart: TChart;
    FListener: TListener;
    procedure ChartExtentChanged(ASender: TObject);
    procedure SetAutoPageSize(AValue: Boolean);
    procedure SetChart(AValue: TChart);
  protected
    procedure Scroll(
      AScrollCode: TScrollCode; var AScrollPos: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property AutoPageSize: Boolean
      read FAutoPageSize write SetAutoPageSize default false;
    property Chart: TChart read FChart write SetChart;
  published
    property Align;
    property Anchors;
    property BidiMode;
    property BorderSpacing;
    property Constraints;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property Kind;
    property LargeChange;
    property Max;
    property Min;
    property PageSize;
    property ParentBidiMode;
    property ParentShowHint;
    property PopupMenu;
    property Position;
    property ShowHint;
    property SmallChange;
    property TabOrder;
    property TabStop;
    property Visible;
  published
    property OnChange;
    property OnContextPopup;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnScroll;
    property OnStartDrag;
    property OnUTF8KeyPress;
  end;

  { TChartNavPanel }

  TChartNavPanel = class(TCustomControl)
  private
    FChart: TChart;
    FFullExtentPen: TPen;
    FListener: TListener;
    FLogicalExtentPen: TPen;
    FProportional: Boolean;
    procedure ChartExtentChanged(ASender: TObject);
    procedure SetChart(AValue: TChart);
    procedure SetFullExtentPen(AValue: TPen);
    procedure SetLogicalExtentPen(AValue: TPen);
    procedure SetProportional(AValue: Boolean);
  private
    FLogicalExtentRect: TRect;
    FOffset: TDoublePoint;
    FPrevPoint: TDoublePoint;
    FScale: TDoublePoint;
  protected
    procedure MouseDown(
      AButton: TMouseButton; AShift: TShiftState; AX, AY: Integer); override;
    procedure MouseMove(AShift: TShiftState; AX, AY: Integer); override;
    procedure MouseUp(
      AButton: TMouseButton; AShift: TShiftState; AX, AY: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Paint; override;
  published
    property Chart: TChart read FChart write SetChart;
    property FullExtentPen: TPen read FFullExtentPen write SetFullExtentPen;
    property LogicalExtentPen: TPen read FLogicalExtentPen write SetLogicalExtentPen;
    property Proportional: Boolean read FProportional write SetProportional default false;
  published
    property Align;
  end;

procedure Register;

implementation

uses
  Forms, SysUtils, TAGeometry;

procedure Register;
begin
  RegisterComponents(
    CHART_COMPONENT_IDE_PAGE, [TChartNavScrollBar, TChartNavPanel]);
end;

{ TChartNavScrollBar }

procedure TChartNavScrollBar.ChartExtentChanged(ASender: TObject);
var
  fe, le: TDoubleRect;
  fw, lw: Double;
begin
  Unused(ASender);
  if Chart = nil then exit;
  fe := Chart.GetFullExtent;
  le := Chart.LogicalExtent;
  case Kind of
    sbHorizontal: begin
      fw := fe.b.X - fe.a.X;
      if fw <= 0 then
        Position := 0
      else
        Position := Round(WeightedAverage(Min, Max, (le.a.X - fe.a.X) / fw));
      lw := le.b.X - le.a.X;
    end;
    sbVertical: begin
      fw := fe.b.Y - fe.a.Y;
      if fw <= 0 then
        Position := 0
      else
        Position := Round(WeightedAverage(Max, Min, (le.a.Y - fe.a.Y) / fw));
      lw := le.b.Y - le.a.Y;
    end;
  end;
  if AutoPageSize and not (csDesigning in ComponentState) then
    PageSize := Round(lw / fw * (Max - Min));
end;

constructor TChartNavScrollBar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FListener := TListener.Create(@FChart, @ChartExtentChanged);
end;

destructor TChartNavScrollBar.Destroy;
begin
  FreeAndNil(FListener);
  inherited Destroy;
end;

procedure TChartNavScrollBar.Scroll(
  AScrollCode: TScrollCode; var AScrollPos: Integer);
var
  fe, le: TDoubleRect;
  d, w: Double;
begin
  inherited Scroll(AScrollCode, AScrollPos);
  if Chart = nil then exit;
  w := Max - Min;
  if w = 0 then exit;
  fe := Chart.GetFullExtent;
  le := Chart.LogicalExtent;
  case Kind of
    sbHorizontal: begin
      d := WeightedAverage(fe.a.X, fe.b.X, Position / w);
      le.b.X += d - le.a.X;
      le.a.X := d;
    end;
    sbVertical: begin
      d := WeightedAverage(fe.b.Y, fe.a.Y, Position / w);
      le.b.Y += d - le.a.Y;
      le.a.Y := d;
    end;
  end;
  Chart.LogicalExtent := le;
  // Focused ScrollBar is glitchy under Win32, especially after PageSize change.
  Chart.SetFocus;
end;

procedure TChartNavScrollBar.SetAutoPageSize(AValue: Boolean);
begin
  if FAutoPageSize = AValue then exit;
  FAutoPageSize := AValue;
  ChartExtentChanged(Self);
end;

procedure TChartNavScrollBar.SetChart(AValue: TChart);
begin
  if FChart = AValue then exit;

  if FListener.IsListening then
    FChart.ExtentBroadcaster.Unsubscribe(FListener);
  FChart := AValue;
  if FChart <> nil then
    FChart.ExtentBroadcaster.Subscribe(FListener);
  ChartExtentChanged(Self);
end;

{ TChartNavPanel }

procedure TChartNavPanel.ChartExtentChanged(ASender: TObject);
begin
  Unused(ASender);
  Invalidate;
end;

constructor TChartNavPanel.Create(AOwner: TComponent);
const
  DEF_WIDTH = 40;
  DEF_HEIGHT = 20;
begin
  inherited Create(AOwner);
  FListener := TListener.Create(@FChart, @ChartExtentChanged);
  FFullExtentPen := TPen.Create;
  FLogicalExtentPen := TPen.Create;
  FLogicalExtentRect := Rect(0, 0, 0, 0);
  Width := DEF_WIDTH;
  Height := DEF_HEIGHT;
end;

destructor TChartNavPanel.Destroy;
begin
  FreeAndNil(FListener);
  FreeAndNil(FFullExtentPen);
  FreeAndNil(FLogicalExtentPen);
  inherited Destroy;
end;

procedure TChartNavPanel.MouseDown(
  AButton: TMouseButton; AShift: TShiftState; AX, AY: Integer);
begin
  if Chart = nil then exit;
  FPrevPoint := (DoublePoint(AX, Height - AY) - FOffset) / FScale;
  MouseCapture :=
    (AShift = [ssLeft]) and IsPointInRect(Point(AX, AY), FLogicalExtentRect);
  if MouseCapture then
    Cursor := crSizeAll;
  inherited MouseDown(AButton, AShift, AX, AY);
end;

procedure TChartNavPanel.MouseMove(AShift: TShiftState; AX, AY: Integer);
var
  p: TDoublePoint;
  le: TDoubleRect;
begin
  if Chart = nil then exit;
  if MouseCapture then begin
    p := (DoublePoint(AX, Height - AY) - FOffset) / FScale;
    le := Chart.LogicalExtent;
    le.a += p - FPrevPoint;
    le.b += p - FPrevPoint;
    Chart.LogicalExtent := le;
    FPrevPoint := p;
  end;
  inherited MouseMove(AShift, AX, AY);
end;

procedure TChartNavPanel.MouseUp(
  AButton: TMouseButton; AShift: TShiftState; AX, AY: Integer);
begin
  MouseCapture := false;
  Cursor := crDefault;
  inherited MouseUp(AButton, AShift, AX, AY);
end;

procedure TChartNavPanel.Paint;

  function DrawRect(ARect: TDoubleRect): TRect;
  begin
    with ARect do begin
      a := a * FScale + FOffset;
      b := b * FScale + FOffset;
      Result := Rect(
        Round(a.X), Height - Round(a.Y), Round(b.X), Height - Round(b.Y));
    end;
    Canvas.Rectangle(Result);
  end;

var
  fe, le, ext: TDoubleRect;
  sz: TDoublePoint;
begin
  if Chart = nil then exit;
  fe := Chart.GetFullExtent;
  le := Chart.LogicalExtent;
  ext := fe;
  ExpandRect(ext, le.a);
  ExpandRect(ext, le.b);
  sz := ext.b - ext.a;
  if (sz.X <= 0) or (sz.Y <= 0) then exit;
  FScale := DoublePoint(Width, Height) / sz;
  FOffset := ZeroDoublePoint;
  if Proportional then begin
    if FScale.X < FScale.Y then begin
      FScale.Y := FScale.X;
      FOffset.Y := (Height - sz.Y * FScale.Y) / 2;
    end
    else begin
      FScale.X := FScale.Y;
      FOffset.X := (Width - sz.X * FScale.X) / 2;
    end;
  end;
  FOffset -= ext.a * FScale;

  Canvas.Brush.Color := Chart.BackColor;
  Canvas.Brush.Style := bsSolid;
  Canvas.FillRect(ClientRect);
  Canvas.Brush.Style := bsClear;
  Canvas.Pen := FullExtentPen;
  DrawRect(fe);
  Canvas.Pen := LogicalExtentPen;
  FLogicalExtentRect := DrawRect(le);
end;

procedure TChartNavPanel.SetChart(AValue: TChart);
begin
  if FChart = AValue then exit;

  if FListener.IsListening then
    FChart.ExtentBroadcaster.Unsubscribe(FListener);
  FChart := AValue;
  if FChart <> nil then
    FChart.ExtentBroadcaster.Subscribe(FListener);
  ChartExtentChanged(Self);
end;

procedure TChartNavPanel.SetFullExtentPen(AValue: TPen);
begin
  if FFullExtentPen = AValue then exit;
  FFullExtentPen := AValue;
  Invalidate;
end;

procedure TChartNavPanel.SetLogicalExtentPen(AValue: TPen);
begin
  if FLogicalExtentPen = AValue then exit;
  FLogicalExtentPen := AValue;
  Invalidate;
end;

procedure TChartNavPanel.SetProportional(AValue: Boolean);
begin
  if FProportional = AValue then exit;
  FProportional := AValue;
  Invalidate;
end;

end.

