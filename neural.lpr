program neural;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Classes, SysUtils, CustApp,
  { you can add units after this }
  neuralnetwork, neuralvolume, Math, neuraldatasets, neuralfit, neuralopencl;

type

  { TNeural }

  TNeural = class(TCustomApplication)
  protected
    procedure DoRun; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteHelp; virtual;
  end;

{ TNeural }

procedure TNeural.DoRun;
var
    ErrorMsg: String;
    NN: TNNet;
    NeuralFit: TNeuralImageFit;
    ImgTrainingVolumes, ImgValidationVolumes, ImgTestVolumes: TNNetVolumeList;
    EasyOpenCL: TEasyOpenCL;
    ProportionToLoad : single;
begin
  // quick check parameters
  ErrorMsg:=CheckOptions('h', 'help');
  if ErrorMsg<>'' then begin
    ShowException(Exception.Create(ErrorMsg));
    Terminate;
    Exit;
  end;

  // parse parameters
  if HasOption('h', 'help') then begin
    WriteHelp;
    Terminate;
    Exit;
  end;
    { add your program here }
    // Usando o OpenCL
    EasyOpenCL := TEasyOpenCL.Create();
    WriteLn('Setting platform to: ', EasyOpenCL.PlatformNames[0]);
    EasyOpenCL.SetCurrentPlatform(EasyOpenCL.PlatformIds[0]);
    WriteLn('Setting device to: ', EasyOpenCL.DeviceNames[0]);

    // Vamos criar a rede Neural
    WriteLn('Criando rede neural...');
    EasyOpenCL.SetCurrentDevice(EasyOpenCL.Devices[0]);
    NN := TNNet.Create();
    NN.AddLayer( TNNetInput.Create(28, 28, 1) );
    NN.AddLayer( TNNetConvolution.Create(6, 5, 0, 1) );
    NN.AddLayer( TNNetMaxPool.Create(2) );
    NN.AddLayer( TNNetConvolution.Create(16, 5, 0, 1) );
    NN.AddLayer( TNNetMaxPool.Create(2) );
    NN.AddLayer( TNNetFullConnect.Create(120) );
    NN.AddLayer( TNNetFullConnect.Create(84) );
    NN.AddLayer( TNNetFullConnectLinear.Create(10) );
    NN.AddLayer( TNNetSoftMax.Create() );

    ProportionToLoad := 1;
    WriteLn('Loading ', Round(ProportionToLoad*100), '% of the dataset into memory.');

    CreateVolumesFromImagesFromFolder
    (
    ImgTrainingVolumes, ImgValidationVolumes, ImgTestVolumes,
    {FolderName=}'tiny-imagenet-200/train', {pImageSubFolder=}'images',
    {color_encoding=}0{RGB},
    {TrainingProp=}0.9*ProportionToLoad,
    {ValidationProp=}0.05*ProportionToLoad,
    {TestProp=}0.05*ProportionToLoad,
    {NewSizeX=}64, {NewSizeY=}64
    );

    WriteLn
    (
      'Training Images:', ImgTrainingVolumes.Count,
      ' Validation Images:', ImgValidationVolumes.Count,
      ' Test Images:', ImgTestVolumes.Count
    );


    NeuralFit := TNeuralImageFit.Create;
    NeuralFit.FileNameBase := 'LOLA';
    NeuralFit.InitialLearningRate := 0.001;
    NeuralFit.LearningRateDecay := 0.01;
    NeuralFit.StaircaseEpochs := 10;
    NeuralFit.Inertia := 0.9;
    NeuralFit.L2Decay := 0.00001;
    NeuralFit.EnableOpenCL(EasyOpenCL.PlatformIds[0], EasyOpenCL.Devices[1]);
    NeuralFit.Fit(NN, ImgTrainingVolumes, ImgValidationVolumes, ImgTestVolumes, {NumClasses=}3, {batchsize=}128, {epochs=}400);
    NeuralFit.Free;

    EasyOpenCL.Free;
    NN.Free;
    ImgTestVolumes.Free;
    ImgValidationVolumes.Free;
    ImgTrainingVolumes.Free;



  // stop program loop
  Terminate;
end;

constructor TNeural.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  StopOnException:=True;
end;

destructor TNeural.Destroy;
begin
  inherited Destroy;
end;

procedure TNeural.WriteHelp;
begin
  { add your help code here }
  writeln('Usage: ', ExeName, ' -h');
end;

var
  Application: TNeural;

{$R *.res}

begin
  Application:=TNeural.Create(nil);
  Application.Title:='LOLA';
  Application.Run;
  Application.Free;
end.

