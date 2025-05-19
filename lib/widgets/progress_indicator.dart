import 'package:flutter/material.dart';

class ChildAddProgressIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String> stepLabels;

  const ChildAddProgressIndicator({
    Key? key,
    required this.currentStep,
    required this.totalSteps,
    required this.stepLabels,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Indicateur de progression
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(totalSteps, (index) {
              // Déterminer si cette étape est active, complétée ou future
              bool isActive = index + 1 == currentStep;
              bool isCompleted = index + 1 < currentStep;

              // Cercle avec nombre
              Widget circle = Container(
                width: isActive ? 50.0 : 35.0,
                height: isActive ? 50.0 : 35.0,
                decoration: BoxDecoration(
                  color: isActive 
                      ? Colors.blue 
                      : isCompleted 
                          ? Colors.blue.withOpacity(0.7) 
                          : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive || isCompleted 
                        ? Colors.blue 
                        : Colors.blue.withOpacity(0.5),
                    width: 2.0,
                  ),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: isActive || isCompleted 
                          ? Colors.white 
                          : Colors.blue,
                      fontWeight: isActive 
                          ? FontWeight.bold 
                          : FontWeight.normal,
                      fontSize: isActive ? 24.0 : 18.0,
                    ),
                  ),
                ),
              );

              // Ajouter un élément au Row (cercle + ligne si ce n'est pas le dernier)
              return index < totalSteps - 1
                  ? Row(
                      children: [
                        circle,
                        Expanded(
                          child: Container(
                            height: 2.0,
                            color: index < currentStep - 1
                                ? Colors.blue
                                : Colors.blue.withOpacity(0.3),
                          ),
                        ),
                      ],
                    )
                  : circle; // Dernier élément (juste un cercle)
            }),
          ),
        ),
        // Étiquettes sous le fil d'Ariane (optionnel)
        if (stepLabels.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                stepLabels.length,
                (index) => index < stepLabels.length
                    ? Expanded(
                        child: Text(
                          stepLabels[index],
                          textAlign: index == 0
                              ? TextAlign.start
                              : index == stepLabels.length - 1
                                  ? TextAlign.end
                                  : TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: index + 1 == currentStep
                                ? Colors.blue
                                : Colors.grey.shade600,
                            fontWeight: index + 1 == currentStep
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      )
                    : const SizedBox(),
              ),
            ),
          ),
      ],
    );
  }
}

// Version simplifiée pour afficher juste les points et le nombre actif
class SimpleProgressIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const SimpleProgressIndicator({
    Key? key,
    required this.currentStep,
    required this.totalSteps,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(totalSteps, (index) {
          // Déterminer si cette étape est active, complétée ou future
          bool isActive = index + 1 == currentStep;
          bool isCompleted = index + 1 < currentStep;

          return Container(
            width: isActive ? 40.0 : 30.0,
            height: isActive ? 40.0 : 30.0,
            margin: const EdgeInsets.symmetric(horizontal: 6.0),
            decoration: BoxDecoration(
              color: isActive 
                  ? Colors.blue 
                  : isCompleted 
                      ? Colors.blue.withOpacity(0.7) 
                      : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive || isCompleted 
                    ? Colors.blue 
                    : Colors.blue.withOpacity(0.5),
                width: 2.0,
              ),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: isActive || isCompleted 
                      ? Colors.white 
                      : Colors.blue,
                  fontWeight: isActive 
                      ? FontWeight.bold 
                      : FontWeight.normal,
                  fontSize: isActive ? 20.0 : 16.0,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}