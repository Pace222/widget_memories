import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:widget_memories/main.dart';

abstract class ImageEvent {}

class LoadImage extends ImageEvent {
  final File imageFile;

  LoadImage(this.imageFile);
}

class ClearImage extends ImageEvent {}

abstract class ImageState {}

class ImageInitial extends ImageState {}

class ImageLoaded extends ImageState {
  final File imageFile;

  ImageLoaded(this.imageFile);
}

class ImageCleared extends ImageState {}

class ImageBloc extends Bloc<ImageEvent, ImageState> {
  ImageBloc() : super(ImageInitial()) {
    on<LoadImage>((event, emit) {
      emit(ImageLoaded(event.imageFile));
    });

    on<ClearImage>((event, emit) async {
      final file = File(imgFilename);
      if (await file.exists()) {
        await file.delete();
      }
      emit(ImageCleared());
    });
  }
}
