
import 'package:flutter/material.dart';
import 'package:my_app/src/custom/constants.dart';
import 'package:my_app/src/providers/global_provider.dart';
import 'package:provider/provider.dart';


class DetailsPage extends StatefulWidget {
  const DetailsPage({super.key});

  @override
  State<DetailsPage> createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Constants.colorPrimary,
        alignment: Alignment.center,
        child: Column(
          children: [
            SizedBox(height: 100,),
            Text(
              Provider.of<GlobalProvider>(context, listen: false).mToken,
              style: TextStyle(
                color: Constants.colorFont,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20,),
            Text(
              'details page',
              style: TextStyle(
                color: Constants.colorFont,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        ),
      );
  }
}