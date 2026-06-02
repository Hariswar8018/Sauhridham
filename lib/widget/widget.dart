import 'package:flutter/material.dart';

class GlobalWidget{

  static Widget contain(double w,String str,{bool on = false}){
    return Container(
      width: w,
      height: 55,
      decoration: BoxDecoration(
        color: Color(0xff014A8E),
        borderRadius: BorderRadius.circular(10)
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(str,style: TextStyle(color: Colors.white,fontWeight: FontWeight.w600),),
          SizedBox(width: 5,),
          on?Icon(Icons.download_for_offline,color: Colors.white,):Icon(Icons.arrow_forward,color: Colors.white,)
        ],
      ),
    );
  }
  static Widget circular()=>Center(
    child: CircularProgressIndicator(
      backgroundColor: Colors.white,
      color: GlobalWidget.color,
    ),
  );
  static Widget empty(double w,String str )=>Container(
    width: w,height: 90,
    child: Column(
      children: [
        Center(
          child: Image.asset("assets/empty.png",height: 70,),
        ),
        Center(child: Text(str,style: TextStyle(fontWeight: FontWeight.w600),))
      ],
    ),
  );

  static Color color = Color(0xff014A8E);
}