//+------------------------------------------------------------------+
//|                                                 CurrencyInfo.mq5 |
//|                                     Copyright 2020,Akimasa Ohara |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Akimasa Ohara"
#property link      "https://www.mql5.com"
#property version   "1.03"

#include <Logging\Logger.mqh>
#include <File\FileOutLog.mqh>
#include <Others\DST\DST.mqh>
#include <Others\NewBar\NewBar.mqh>

//---input変数（共有変数）-----------------------------------------------
input ulong MagicNumber = 123456789; // マジックナンバー
input bool IsUK = false;           // サマータイム判定時に利用(初期値oanda)
// alpari : ヨーロッパ
// oanda : アメリカ（予想）
enum LOGLEVEL{
   NONE  = 7,
   FATAL = 6,
   ERROR = 5,  
   WARN  = 4,
   INFO  = 3,
   DEBUG = 2,
   TRACE = 1
};
input LOGLEVEL LogLevel = 2;       // ログレベル

// ボリンジャー用の変数--変更(追加) 2022/07/11 データ収集項目ボリンジャー位置の追加のため
input int            MainBollin_Period    = 1120;              // メインボリンジャーの期間
input double         MainBollin_Entry_Dev = 1.0;               // メインボリンジャーの標準偏差(エントリー用)
input int            SubBollin_Period     = 303;               // サブボリンジャーの期間
input double         SubBollin_Dev        = 0.0;               // サブボリンジャーの標準偏差
input ENUM_APPLIED_PRICE   Applied_Price     = PRICE_CLOSE;    // 価格の種類(PRICE_CLOSE:終値, PRICE_OPEN:始値, PRICE_HIGH:高値, PRICE_LOW:低値)

//---グローバル変数---------------------------------------------
datetime SystemDate;              //　最終入力のシステム日時
string SysDateFileName;           // システムデータファイル名(File名： [symbolName][timeFrame]_SystemDate.dat  例： EUCUSDM1_SystemDate.dat)
int TickNum = 0;                  // Tick数
double Spread = 0;                // スプレッド総数

// 指標ハンドル変数---変更(追加) 2022/07/11 データ収集項目ボリンジャー位置の追加のため
int mainBoll_Entry_Handle;    // メインボリンジャー（エントリー用）のハンドル
int mainBoll_Check_Handle;    // メインボリンジャー（チェック用）のハンドル
int subBoll_Handle;           // サブボリンジャーのハンドル

// 指標配列変数---変更(追加) 2022/07/11 データ収集項目ボリンジャー位置の追加のため
double mainBoll_Entry_High[];    // メインボリンジャー（エントリー用）Highをコピーするための配列
double mainBoll_Entry_Low[];     // メインボリンジャー（エントリー用）Lowをコピーするための配列
double mainBoll_Entry_Middle[];  // メインボリンジャー（エントリー用）Middleをコピーするための配列
double subBoll_Middle[];         // サブボリンジャー　Middleをコピーするための配列

// 共通情報変数---変更(追加) 2022/07/11 データ収集項目ボリンジャー位置の追加のため
string timeFrameSymbol;    // 銘柄情報

// FileOutLogクラス，ログクラスのインスタンス生成
FileOutLog *file = new FileOutLog(MagicNumber, LogLevel);
Logger *logger = new Logger(MagicNumber, LogLevel, "CurrencyInfo"); 


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(){
  
   // OnInit処理用のprocessIDを発行
   MathSrand(GetTickCount());
   int processID = MathRand();
   
   // --ログ出力（スタート）
   logger.info(processID, true, "ONINIT", "-");
  
   // チャートウィンドウの銘柄名を取得
   string symbolName = Symbol();
   // チャートウィンドウの時間足を取得 
   string timeFrame = gettimeFrameName();
  
   // 時間足チェック
   if(timeFrame == ""){
      logger.error(processID, false, "ONINIT", "ERROR_TIMEFRAME");
      Alert("【ERROR】Could not get timeline");
      return(INIT_FAILED);
   }

   //　データファイル名を生成
   string fileName;
   StringConcatenate(fileName, symbolName, timeFrame, ".csv"); 
   // システムデータファイル名を生成
   StringConcatenate(SysDateFileName, symbolName, timeFrame, "_SystemDate.dat"); 

   // データファイルが存在するかを取得
   bool existInputFile = file.IsExist(processID, fileName);

   // データファイルを開くor作成
   int fileHandle = file.Open(processID, fileName, FILE_READ|FILE_WRITE|FILE_TXT, ',');
    
   // エラーチェック(Open)
   if(file.procResult == 2){
      logger.error(processID, false, "ONINIT", "ERROR_OPEN_FILE(Code:" + IntegerToString(file.ErrorCode) + ")");
      Alert("【ERROR】Error opening file");
      return(INIT_FAILED);
   }
   
   // 銘柄情報を取得--変更(追加) 2022/07/11 データ収集項目ボリンジャー位置の追加のため
   timeFrameSymbol = Symbol();
   
   // 指標ハンドルの生成---変更(追加) 2022/07/11 データ収集項目ボリンジャー位置の追加のため
   mainBoll_Entry_Handle = iBands(timeFrameSymbol, PERIOD_CURRENT, MainBollin_Period, 0, MainBollin_Entry_Dev, Applied_Price);
   mainBoll_Check_Handle = iBands(timeFrameSymbol, PERIOD_CURRENT, MainBollin_Period, 0, MainBollin_Entry_Dev, Applied_Price);
   subBoll_Handle        = iBands(timeFrameSymbol, PERIOD_CURRENT, SubBollin_Period , 0, SubBollin_Dev       , Applied_Price);
   if(mainBoll_Entry_Handle < 0){
      logger.error(processID, false, "ONINIT", "ERROR_GETHANDLE_MAIN_E");
      Alert("【ERROR】ボリンジャーバンド（メイン）のハンドル取得に失敗しました");
      return(INIT_FAILED);
   }
   if(mainBoll_Check_Handle < 0){
      logger.error(processID, false, "ONINIT", "ERROR_GETHANDLE_MAIN_C");
      Alert("【ERROR】ボリンジャーバンド（メイン）のハンドル取得に失敗しました");
      return(INIT_FAILED);
   }
   if(subBoll_Handle < 0){
      logger.error(processID, false, "ONINIT", "ERROR_GETHANDLE_SUB");
      Alert("【ERROR】ボリンジャーバンド（サブ）のハンドル取得に失敗しました");
      return(INIT_FAILED);
   }
  
   //　データファイルが存在する
   if(existInputFile == true){
      // データファイルの最終行を取得（OnTick時の入力の準備）
      file.Seek(processID, 0, SEEK_END);
      if(file.procResult == 2){
         logger.error(processID, false, "ONINIT", "ERROR_SEEK_FILE(Code:" + IntegerToString(file.ErrorCode) + ")");
         Alert("【ERROR】Error seeking file");
         return(INIT_FAILED);
      }
  
  
      //--システムデータファイルから最終データのシステム日付を取得--------------------------
      // FileOutLogクラスのインスタンス生成
      FileOutLog *sysDateFile = new FileOutLog(MagicNumber, LogLevel);  
      
      // FileExist
      if(sysDateFile.IsExist(processID, SysDateFileName) != true){
         logger.error(processID, false, "ONINIT", "ERROR_NOT_FOUND_SYSTEMDATEFILE(Code:" + IntegerToString(sysDateFile.ErrorCode) + ")");
         Alert("【ERROR】Not found SystemDate-File");
         return(INIT_FAILED);
      }
   
      // FileOpen
      int sysDateFileHandle = sysDateFile.Open(processID, SysDateFileName, FILE_READ|FILE_TXT, ',');
      if(sysDateFile.procResult == 2){
         logger.error(processID, false, "ONINIT", "ERROR_OPEN_SYSTEMDATEFILE(Code:" + IntegerToString(sysDateFile.ErrorCode) + ")");
         Alert("【ERROR】Error opening SystemDate-File");
         return(INIT_FAILED);
      }
   
      // readLastDate
      string lastWriteDate = sysDateFile.ReadString(processID);      
      if(lastWriteDate == ""){
         logger.error(processID, false, "ONINIT", "ERROR_READ_SYSTEMDATEFILE(Code:" + IntegerToString(sysDateFile.ErrorCode) + ")");
         Alert("【ERROR】Error reading SystemDate-File");
         return(INIT_FAILED);
      }
   
      // FileClose
      sysDateFile.Close(processID);
      if(sysDateFile.procResult == 2){
         logger.error(processID, false, "ONINIT", "ERROR_DELETE_SYSTEMDATEFILE(Code:" + IntegerToString(sysDateFile.ErrorCode) + ")");
         Alert("【ERROR】Error Closing SystemDate-File");
         return(INIT_FAILED);
      }
      
      // FileOutLogクラスのインスタンス削除
      delete sysDateFile;
   
      // 最終入力のシステム日付を取得
      SystemDate = StringToTime(lastWriteDate);
      //------------------------------------------------------------------------
   
   
   }else{
  
      // データファイルにヘッダーを挿入
      file.WriteString(processID, "SystemDate,Date,Week,Time,Time(Japan),SummerTime,Open,Close,High,Low,Volume,Tick,Spread,mainBollEntryHigh,mainBollEntryMiddle,mainBollEntryLow,subBollMiddle\r\n");
      
   }
  
  
//---
   // --ログ出力（エンド）
   logger.info(processID, false, "ONINIT", "OK");
   
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){
//---
   // OnDeInit処理用のprocessIDを発行
   int processID = MathRand();
   
   // --ログ出力（スタート）
   logger.info(processID, true, "ONDEINIT", "");
   
   //  データファイルを閉じる
   file.Close(processID);
   
   // --ログ出力（エンド）
   if(file.procResult == 2){
      logger.error(processID, false, "ONDEINIT", "ERROR_CLOSE_FILE(Code:" + IntegerToString(file.ErrorCode) + ")");
      Alert("【ERROR】Error closing file");
   }else{ 
      logger.info(processID, false, "ONDEINIT", "OK(" + IntegerToString(UninitializeReason()) +")");
   }
   
   // FileOutLogクラス，ログクラスのインスタンス削除
   delete file;
   delete logger;   
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){

   // OnDeInit処理用のprocessIDを発行
   int processID = MathRand();

   // --ログ出力（スタート）（trace用）
   logger.trace(processID, true, "ONTICK", "-");
   
   // Tick数のカウント
   TickNum++;
   
   // スプレッドの加算
   MqlTick tick;
   SymbolInfoTick(Symbol(), tick);
   Spread += tick.ask - tick.bid;
   
   // 新しいバーの出現チェック
   if(NewBar::IsNewBar(Symbol(), Period()) == false){
      // Tickイベント終了
      logger.trace(processID, false, "ONTICK", "NOT_NEWBAR");
      return;
   }
   
   // 日時取得（1ロウソク前）
   datetime current = iTime(Symbol(), Period(), 1);
   MqlDateTime currentStrct;
   TimeToStruct(current, currentStrct);
   
   // システム日付チェック
   if(current <= SystemDate){
      // Tick数の初期化
      TickNum = 1;
      // Tickイベント終了
      logger.trace(processID, false, "ONTICK", "NOT_SYSTEMDATE");
      return;
   }
   
   // --ログ出力（スタート）
   logger.info(processID, true, "ONTICK", "-");
   
   //--データ取得 & 整理---------------------------------------------------------------------------------------------------------
   // 'Date'と'Time'の文字列化
   string currentTime;
   StringConcatenate(currentTime, IntegerToString(currentStrct.hour,2,'0'), ":", IntegerToString(currentStrct.min,2,'0'));
   string currentDay;
   StringConcatenate(currentDay, currentStrct.year, ".", IntegerToString(currentStrct.mon,2,'0'), ".", IntegerToString(currentStrct.day,2,'0'));

   // サマータイムの判定 & 日本時間取得
   string dstNum;
   int currentTimeHourJP;
   if(DST::IsDST(IsUK, current) == true){ 
      dstNum = "0";
      currentTimeHourJP = DST::TimeToJPTime(currentStrct.hour, true);
   }else{
      dstNum = "1";
      currentTimeHourJP = DST::TimeToJPTime(currentStrct.hour, false);
   }
   
   // 日本時間の取得   
   string currentTimeJP;
   StringConcatenate(currentTimeJP, IntegerToString(currentTimeHourJP,2,'0'), ":", IntegerToString(currentStrct.min,2,'0'));
   
   // pip数への変換処理
   double pips_Spread = 0;
   int symbol_Digits = Digits();
   if(symbol_Digits == 3 || symbol_Digits == 5){
      if(symbol_Digits == 3){
         pips_Spread = Spread * 100;
         
      } else if(symbol_Digits==5){
         pips_Spread = Spread * 10000;
      }
   }else{
      pips_Spread = Spread;
   }
   
   // 総数スプレッドをTickの平均で表す  
   if(TickNum-1 == 0){
      pips_Spread = 0;
   }else{
      pips_Spread = pips_Spread / (TickNum-1);
   }
   
   // ボリンジャーバンドの値を取得---変更(追加) 2022/07/11 データ収集項目ボリンジャー位置の追加のため
   if(CopyBuffer(mainBoll_Entry_Handle, UPPER_BAND, 0, 1, mainBoll_Entry_High) == -1){
      logger.error(processID, false, "ONTICK", "ERROR_COPYBOLLIN_HIGH(" + IntegerToString(GetLastError()) + ")");
      return;
   }
   if(CopyBuffer(mainBoll_Entry_Handle, LOWER_BAND, 0, 1, mainBoll_Entry_Low) == -1){
      logger.error(processID, false, "ONTICK", "ERROR_COPYBOLLIN_LOW(" + IntegerToString(GetLastError()) + ")");
      return;
   }
   if(CopyBuffer(mainBoll_Entry_Handle, BASE_LINE , 0, 1, mainBoll_Entry_Middle) == -1){
      logger.error(processID, false, "ONTICK", "ERROR_COPYBOLLIN_MIDDLE(" + IntegerToString(GetLastError()) + ")");
      return;
   }
   if(CopyBuffer(subBoll_Handle       , BASE_LINE , 0, 1, subBoll_Middle) == -1){
      logger.error(processID, false, "ONTICK", "ERROR_COPYBOLLIN_SUB(" + IntegerToString(GetLastError()) + ")");
      return;
   }
   
   //-------------------------------------------------------------------------------------------------------------------------
   
   // 入力データの文字列化
   string inputData; 
   StringConcatenate(inputData,        
      TimeToString(current), ",",                            //システム用日時
      currentDay, ",",                                       //日付
      IntegerToString(currentStrct.day_of_week), ",",        //曜日
      currentTime, ",",                                      //システム時間
      currentTimeJP, ",",                                    //日本時間
      dstNum, ",",                                           //サマータイム   Y(0) / N(1)
      DoubleToString(iOpen(Symbol(), Period(), 1)), ",",     //始値（1ロウソク前）
      DoubleToString(iClose(Symbol(), Period(), 1)), ",",    //終値（1ロウソク前）
      DoubleToString(iHigh(Symbol(), Period(), 1)), ",",     //高値（1ロウソク前）
      DoubleToString(iLow(Symbol(), Period(), 1)), ",",      //低値（1ロウソク前）
      IntegerToString(iVolume(Symbol(), Period(), 1)), ",",  //出来高
      TickNum-1, ",",                                        //Tick数
      DoubleToString(pips_Spread, 1), ",",                   //平均スプレッド
      mainBoll_Entry_High[0], ",",                           //メインボリン+1σ
      mainBoll_Entry_Middle[0], ",",                         //メインボリンセンター
      mainBoll_Entry_Low[0], ",",                            //メインボリン-1σ
      subBoll_Middle[0], "\r\n");                            //サブボリンセンター
      
   // データファイルへ書き込み
   file.WriteString(processID, inputData);
   
   // Tick数の初期化
   TickNum = 1;
   
   // スプレッドの総数を初期化
   Spread = 0;
   
   //--システムデータファイルへ書き込み---------------------------------------------------------------------------------------------------
   // FileOutLogクラスのインスタンス生成
   FileOutLog *sysDateFile = new FileOutLog(MagicNumber, LogLevel);  
      
   // システムデータファイルが存在する場合は削除
   if(sysDateFile.IsExist(processID, SysDateFileName) == true){
      sysDateFile.Delete(processID, SysDateFileName, FILE_READ|FILE_TXT);
      if(sysDateFile.procResult == 2){
         logger.error(processID, false, "ONTICK", "ERROR_DELETE_SYSTEMDATEFILE(Code:" + IntegerToString(sysDateFile.ErrorCode) + ")");
         Alert("【ERROR】Error Deleting SystemDate-File");
         return;
      }
   }
   
   // システムデータファイルを作成
   int sysDateFileHandle = sysDateFile.Open(processID, SysDateFileName, FILE_WRITE|FILE_TXT, ',');
   if(sysDateFile.procResult == 2){
      logger.error(processID, false, "ONTICK", "ERROR_OPEN_SYSTEMDATEFILE(Code:" + IntegerToString(sysDateFile.ErrorCode) + ")");
      Alert("【ERROR】Error opening SystemDate-File");
      return;
   }
      
   // システムデータ書き込み
   sysDateFile.WriteString(processID, TimeToString(current));
   
   // システムデータファイルを閉じる
   sysDateFile.Close(processID);
   if(sysDateFile.procResult == 2){
      logger.error(processID, false, "ONTICK", "ERROR_DELETE_SYSTEMDATEFILE(Code:" + IntegerToString(sysDateFile.ErrorCode) + ")");
      Alert("【ERROR】Error Closing SystemDate-File");
      return;
   }
   
   // FileOutLogクラスのインスタンス削除
   delete sysDateFile;
   
   //-------------------------------------------------------------------------------------------------------------------------
   
   logger.info(processID, false, "ONTICK", "OK");

}
//+------------------------------------------------------------------+

string gettimeFrameName(){ 
   switch(Period()){
      case(PERIOD_M1):return("M1");
      case(PERIOD_M5):return("M5");
      case(PERIOD_M10):return("M10");
      case(PERIOD_M15):return("M15");
      case(PERIOD_M20):return("M20");
      case(PERIOD_M30):return("M30");
      case(PERIOD_H1):return("H1");
      case(PERIOD_H4):return("H4");
      case(PERIOD_H12):return("H12");
      case(PERIOD_D1):return("D1");
      case(PERIOD_W1):return("W1");
      default:return("");
   }
   
}